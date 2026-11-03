import ComposableArchitecture
import Testing
import UserNotificationDomainInterface
@testable import Festival

@MainActor
struct FestivalNotificationBadgeTests {
  @Test("종 버튼은 로그인 상태에서만 알림함을 요청하고 로그아웃은 배지를 지운다")
  func notificationEntryAndAccountChange() async {
    var state = FestivalFeature.State()
    state.hasSession = true
    state.notificationUnreadCount = 3
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.view(.notificationTapped))
    await store.receive(.delegate(.notificationInboxRequested))
    await store.send(.view(.accountChanged)) {
      $0.hasSession = false
      $0.notificationUnreadCount = 0
      $0.accountGeneration = 1
    }
    await store.send(.view(.notificationTapped))
    await store.receive(.delegate(.loginRequested))
  }

  @Test("이전 계정의 늦은 배지 응답은 버린다")
  func staleUnreadCountIsIgnored() async {
    var state = FestivalFeature.State()
    state.hasSession = true
    state.accountGeneration = 2
    let store = TestStore(initialState: state) { FestivalFeature() }

    await store.send(.inner(.notificationUnreadCountLoaded(5, generation: 1)))
    await store.send(.view(.notificationUnreadCountChanged(2))) {
      $0.notificationUnreadCount = 2
    }
  }

  @Test("읽음 요청 실패 뒤에도 보드가 배지를 다시 조회한다")
  func failedReadRefreshesUnreadCount() async {
    let calls = LockIsolated(0)
    var state = FestivalFeature.State()
    state.hasSession = true
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.userNotificationUseCase = MockUserNotificationUseCase(
        unreadCount: { 3 },
        markRead: { ids in
          #expect(ids == ["new"])
          calls.withValue { $0 += 1 }
          throw UserNotificationError.unavailable
        }
      )
    }

    await store.send(.async(.markNotificationRead("new")))
    await store.receive(\.async.loadNotificationUnreadCount)
    await store.receive(\.inner.notificationUnreadCountLoaded) {
      $0.notificationUnreadCount = 3
    }
    #expect(calls.value == 1)
  }
}
