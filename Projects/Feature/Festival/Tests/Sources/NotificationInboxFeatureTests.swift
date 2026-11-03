import ComposableArchitecture
import FestiCoreSharedUI
import FestiCoreUtility
import Foundation
import Testing
import UserNotificationDomainInterface
@testable import Festival

@MainActor
struct NotificationInboxFeatureTests {
  @Test("서울 자정 기준으로 오늘과 어제를 나눈다")
  func sectionsUseSeoulCalendar() throws {
    let now = try #require(AppDateFormat.calendar.date(from:
      .init(year: 2026, month: 11, day: 4, hour: 0, minute: 10)
    ))
    let today = try #require(AppDateFormat.calendar.date(from:
      .init(year: 2026, month: 11, day: 4, hour: 0, minute: 5)
    ))
    let yesterday = try #require(AppDateFormat.calendar.date(from:
      .init(year: 2026, month: 11, day: 3, hour: 23, minute: 50)
    ))
    let sections = NotificationInboxPresentation.sections([
      item(id: "today", createdAt: today), item(id: "yesterday", createdAt: yesterday)
    ], now: now)

    #expect(sections.map(\.title) == ["오늘", "어제"])
    #expect(NotificationInboxPresentation.time(for: sections[0].items[0], now: now) == "5분 전")
    #expect(NotificationInboxPresentation.time(for: sections[1].items[0], now: now) == "어제 23:50")
  }

  @Test("읽은 알림은 다시 읽음 요청하지 않고 일치하는 라이브 경로만 연다")
  func readItemOpensMatchingFestival() async {
    let calls = LockIsolated(0)
    var state = NotificationInboxFeature.State()
    state.load = .loaded
    state.items = [item(id: "read", readAt: .distantPast, route: "/festivals/fst/live")]
    let store = TestStore(initialState: state) { NotificationInboxFeature() } withDependencies: {
      $0.userNotificationUseCase = MockUserNotificationUseCase(markRead: { _ in calls.withValue { $0 += 1 } })
    }

    await store.send(.view(.rowTapped("read")))
    await store.receive(.delegate(.rowOpened(festivalID: "fst", markReadID: nil)))
    #expect(calls.value == 0)
  }

  @Test("일치하지 않는 목적지는 알림함에 남겨 공용 팝업으로 안내한다")
  func unsupportedRouteStaysInInbox() async {
    var state = NotificationInboxFeature.State()
    state.load = .loaded
    state.items = [item(id: "other", readAt: .distantPast, route: "/festivals/other/live")]
    let store = TestStore(initialState: state) { NotificationInboxFeature() }

    await store.send(.view(.rowTapped("other"))) {
      $0.alert = .alert(
        title: "아직 열 수 없는 알림이에요",
        message: "해당 화면을 준비 중입니다.",
        cancelTitle: "닫기"
      )
    }
    await store.send(.alert(.presented(.confirmTapped))) { $0.alert = nil }
  }

  @Test("읽지 않은 알림은 즉시 목적지를 열고 읽음 요청은 보드에 위임한다")
  func unreadItemOpensImmediately() async {
    var state = NotificationInboxFeature.State()
    state.load = .loaded
    state.items = [item(id: "new", route: "/festivals/fst/live")]
    let store = TestStore(initialState: state) { NotificationInboxFeature() }

    await store.send(.view(.rowTapped("new"))) {
      $0.locallyReadIDs = ["new"]
      $0.attemptedReadIDs = ["new"]
    }
    await store.receive(.delegate(.rowOpened(festivalID: "fst", markReadID: "new")))
    await store.send(.view(.rowTapped("new")))
    await store.receive(.delegate(.rowOpened(festivalID: "fst", markReadID: nil)))
  }

  @Test("불러온 알림을 모두 지워도 다음 페이지가 있으면 이어서 불러온다")
  func deletingLoadedPageFetchesNextItems() async {
    var state = NotificationInboxFeature.State()
    state.load = .loaded
    state.items = [item(id: "first")]
    state.nextCursor = "next"
    state.isEditing = true
    state.isDeleting = true
    state.selectedIDs = ["first"]
    let store = TestStore(initialState: state) { NotificationInboxFeature() } withDependencies: {
      $0.userNotificationUseCase = MockUserNotificationUseCase(
        notifications: { cursor in
          #expect(cursor == nil)
          return UserNotificationPage(items: [item(id: "remaining")], nextCursor: nil)
        },
        unreadCount: { 1 }
      )
    }
    await store.send(.inner(.deleteSucceeded(state.instanceID, ["first"]))) {
      $0.items = []
      $0.nextCursor = nil
      $0.isEditing = false
      $0.isDeleting = false
      $0.selectedIDs = []
      $0.load = .loading
    }
    await store.receive(\.async.fetchPage)
    await store.receive(\.async.refreshUnreadCount)
    await store.receive(\.inner.pageLoaded) {
      $0.items = [item(id: "remaining")]
      $0.load = .loaded
    }
    await store.receive(\.inner.unreadCountLoaded)
    await store.receive(.delegate(.unreadCountChanged(1)))
    #expect(store.state.items.map(\.id) == ["remaining"])
    #expect(store.state.load == .loaded)
    #expect(!store.state.isEditing)
  }

  @Test("다음 페이지는 이미 불러온 알림 ID를 중복으로 붙이지 않는다")
  func nextPageDeduplicatesItems() async {
    var state = NotificationInboxFeature.State()
    state.load = .loaded
    state.items = [item(id: "first")]
    state.nextCursor = "next"
    let store = TestStore(initialState: state) { NotificationInboxFeature() } withDependencies: {
      $0.userNotificationUseCase = MockUserNotificationUseCase(notifications: { cursor in
        #expect(cursor == "next")
        return UserNotificationPage(items: [item(id: "first"), item(id: "second")], nextCursor: nil)
      })
    }
    await store.send(.view(.loadMoreTapped)) { $0.isLoadingMore = true }
    await store.receive(\.async.fetchPage)
    await store.receive(\.inner.pageLoaded) {
      $0.items = [item(id: "first"), item(id: "second")]
      $0.nextCursor = nil
      $0.isLoadingMore = false
    }
    #expect(store.state.items.map(\.id) == ["first", "second"])
    #expect(!store.state.isLoadingMore)
  }

  @Test("목록이 가려진 로딩·오류 상태에서는 선택과 삭제를 시작하지 않는다")
  func hiddenItemsCannotBeEdited() async {
    for load in [NotificationInboxFeature.Load.loading, .failed] {
      var state = NotificationInboxFeature.State()
      state.load = load
      state.items = [item(id: "stale")]
      state.selectedIDs = ["stale"]
      let store = TestStore(initialState: state) { NotificationInboxFeature() }

      await store.send(.view(.editTapped))
      await store.send(.view(.selectAllTapped))
      await store.send(.view(.deleteTapped))
    }
  }

  @Test("전체 재조회는 사라진 알림의 선택을 제거한다")
  func fullReloadPrunesSelection() async {
    var state = NotificationInboxFeature.State()
    state.load = .loading
    state.items = [item(id: "old")]
    state.isEditing = true
    state.selectedIDs = ["old"]
    let store = TestStore(initialState: state) { NotificationInboxFeature() }

    await store.send(.inner(.pageLoaded(
      state.instanceID,
      UserNotificationPage(items: [item(id: "new")], nextCursor: nil),
      requestedCursor: nil
    ))) {
      $0.items = [item(id: "new")]
      $0.selectedIDs = []
      $0.load = .loaded
    }
    #expect(!store.state.allLoadedSelected)
  }

  @Test("이전 알림함의 늦은 응답은 새 알림함에 반영하지 않는다")
  func staleInstanceResponsesAreIgnored() async {
    let state = NotificationInboxFeature.State()
    let store = TestStore(initialState: state) { NotificationInboxFeature() }
    let oldInstanceID = UUID()

    await store.send(.inner(.unreadCountLoaded(oldInstanceID, 99)))
    await store.send(.inner(.deleteFailed(oldInstanceID)))
    await store.send(.inner(.pageLoaded(
      oldInstanceID,
      UserNotificationPage(items: [item(id: "other-account")], nextCursor: nil),
      requestedCursor: nil
    )))
  }

  @Test("다음 페이지를 불러오는 중에는 선택 삭제를 시작하지 않는다")
  func paginationPreventsEditing() async {
    var state = NotificationInboxFeature.State()
    state.load = .loaded
    state.items = [item(id: "first")]
    state.isLoadingMore = true
    let store = TestStore(initialState: state) { NotificationInboxFeature() }

    await store.send(.view(.editTapped))
    #expect(!store.state.isEditing)
  }

  @Test("읽음 요청을 시도한 알림은 전체 재조회 후 다시 전송하지 않는다")
  func fullReloadDoesNotDuplicateReadRequest() async {
    var state = NotificationInboxFeature.State()
    state.load = .loaded
    state.items = [item(id: "new", route: "/festivals/fst/live")]
    let store = TestStore(initialState: state) { NotificationInboxFeature() }

    await store.send(.view(.rowTapped("new"))) {
      $0.locallyReadIDs = ["new"]
      $0.attemptedReadIDs = ["new"]
    }
    await store.receive(.delegate(.rowOpened(festivalID: "fst", markReadID: "new")))
    await store.send(.inner(.pageLoaded(
      state.instanceID,
      UserNotificationPage(items: [item(id: "new", route: "/festivals/fst/live")], nextCursor: nil),
      requestedCursor: nil
    ))) { $0.locallyReadIDs = [] }
    await store.send(.view(.rowTapped("new")))
    await store.receive(.delegate(.rowOpened(festivalID: "fst", markReadID: nil)))
  }
}

private func item(
  id: String,
  createdAt: Date = .distantPast,
  readAt: Date? = nil,
  route: String? = nil
) -> UserNotificationItem {
  UserNotificationItem(
    id: id,
    type: "festival.start",
    festivalID: "fst",
    title: "공연 시작",
    body: "곧 시작합니다",
    createdAt: createdAt,
    readAt: readAt,
    route: route
  )
}
