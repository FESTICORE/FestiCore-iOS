import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
@Suite("깃발 상세")
struct FestivalFlagDetailFeatureTests {
  private nonisolated static let now = Date(timeIntervalSince1970: 1_794_052_800)

  @Test("화면에 들어오면 상세를 불러와 보인다")
  func loadsDetailOnAppear() async {
    let clock = TestClock()
    let detail = Self.detail()
    let store = makeStore(
      clock: clock,
      detail: { _ in return detail }
    )

    await store.send(.view(.onAppear)) {
      $0.loadGeneration = 1
    }
    await store.receive(\.async.load)
    await store.receive(\.async.startClock)
    await store.receive(\.inner.loaded) {
      $0.content = .loaded(detail)
      $0.lastLoadedAt = Self.now
    }
    await store.send(.view(.onDisappear)) {
      $0.loadGeneration = 2
    }
  }

  @Test("첫 조회가 실패하면 없는 깃발과 일시 오류를 나눈다")
  func firstFailureShowsNotFoundOrRetry() async {
    let cases = [
      FailureCase(
        error: .notFound,
        failure: .notFound
      ),
      FailureCase(
        error: .unavailable,
        failure: .unavailable
      ),
      FailureCase(
        error: .invalidResponse,
        failure: .unavailable
      ),
    ]
    for item in cases {
      let error = item.error
      let failure = item.failure
      let store = makeStore(detail: { _ throws(FestivalFlagDetailError) in throw error })
      await store.send(.view(.retryTapped)) {
        $0.loadGeneration = 1
      }
      await store.receive(\.async.load)
      await store.receive(\.inner.loadFailed) {
        $0.content = .failed(failure)
      }
    }
  }

  @Test("받은 상세가 있는데 다시 불러오지 못하면 마지막 상세를 두고 오프라인으로 알린다")
  func refreshFailureKeepsLastDetailAsOffline() async {
    var state = Self.state()
    state.content = .loaded(Self.detail())
    state.lastLoadedAt = Self.now.addingTimeInterval(-180)
    let store = makeStore(
      state: state,
      detail: { _ throws(FestivalFlagDetailError) in throw .unavailable }
    )

    await store.send(.view(.retryTapped)) {
      $0.loadGeneration = 1
    }
    await store.receive(\.async.load)
    await store.receive(\.inner.loadFailed) {
      $0.isOffline = true
    }
    #expect(store.state.offlineText == "오프라인 · 3분 전 정보")
    #expect(store.state.nowCard == .located(
      zone: "리벳 스테이지 앞 왼쪽",
      activity: "슬램",
      source: "마지막으로 받은 정보예요",
      isMuted: true
    ))
    // 오프라인이면 팔로우를 바꾸지 않는다.
    await store.send(.view(.followTapped))
  }

  @Test("이전 세대의 늦은 응답은 버린다")
  func staleGenerationIsIgnored() async {
    let store = makeStore()
    store.exhaustivity = .off
    await store.send(.inner(.loaded(
      generation: 7,
      detail: Self.detail(),
      at: Self.now
    )))
    #expect(store.state.content == .loading)
    await store.send(.inner(.loadFailed(
      generation: 7,
      error: .notFound
    )))
    #expect(store.state.content == .loading)
  }

  @Test("로그인하지 않았으면 팔로우 대신 로그인을 요청한다")
  func followWithoutSessionRequestsLogin() async {
    var state = Self.state(hasSession: false)
    state.content = .loaded(Self.detail())
    let store = makeStore(state: state)

    await store.send(.view(.followTapped))
    await store.receive(\.delegate.loginRequested)
  }

  @Test("팔로우 결과를 버튼과 팔로워 수에 반영한다")
  func followSuccessUpdatesButtonAndCount() async {
    let calls = LockIsolated<[Bool]>([])
    var state = Self.state()
    state.content = .loaded(Self.detail())
    let store = makeStore(
      state: state,
      setFollowing: { following, flagID throws(FestivalFlagFollowError) in
        calls.withValue { $0.append(following) }
        return FestivalFlagFollowResult(
          flagID: flagID,
          isFollowing: true,
          followerCount: 1_285
        )
      }
    )

    await store.send(.view(.followTapped)) {
      $0.isFollowPending = true
    }
    await store.receive(\.async.follow)
    await store.receive(\.inner.followFinished) {
      $0.isFollowPending = false
      $0.followOverride = .init(
        isFollowing: true,
        followerCount: 1_285
      )
    }
    #expect(calls.value == [true])
    #expect(store.state.isFollowing)
    #expect(store.state.followerCount == 1_285)
  }

  @Test("팔로우 실패는 로그인·약관 요청이나 안내로 처리한다")
  func followFailuresAreRouted() async {
    let loginStore = makeLoadedStore(failing: .loginRequired)
    await loginStore.send(.view(.followTapped)) { $0.isFollowPending = true }
    await loginStore.receive(\.async.follow)
    await loginStore.receive(\.inner.followFinished) { $0.isFollowPending = false }
    await loginStore.receive(\.delegate.loginRequested)

    let termsStore = makeLoadedStore(failing: .termsRequired)
    await termsStore.send(.view(.followTapped)) { $0.isFollowPending = true }
    await termsStore.receive(\.async.follow)
    await termsStore.receive(\.inner.followFinished) { $0.isFollowPending = false }
    await termsStore.receive(\.delegate.termsAcceptanceRequested)

    let clock = TestClock()
    let limitStore = makeLoadedStore(
      failing: .limitReached,
      clock: clock
    )
    await limitStore.send(.view(.followTapped)) { $0.isFollowPending = true }
    await limitStore.receive(\.async.follow)
    await limitStore.receive(\.inner.followFinished) { $0.isFollowPending = false }
    await limitStore.receive(\.async.showToast) { $0.toast = "팔로우는 100개까지 할 수 있어요" }
    await clock.advance(by: .seconds(2))
    await limitStore.receive(\.inner.toastExpired) { $0.toast = nil }
  }

  @Test("화면을 떠나면 팔로우 요청을 멈추고 늦은 응답은 버린다")
  func leavingCancelsFollowAndIgnoresLateResponse() async {
    var state = Self.state()
    state.content = .loaded(Self.detail())
    state.isFollowPending = true
    let store = makeStore(state: state)

    await store.send(.view(.onDisappear)) {
      $0.loadGeneration = 1
      $0.isFollowPending = false
    }
    // 로그인 요청 응답이 늦게 와도 부모에게 알리지 않는다.
    await store.send(.inner(.followFinished(.failure(.loginRequired))))
  }

  @Test("지금 카드는 상태와 경과 시간에 따라 문구를 바꾼다")
  func nowCardFollowsStatusAndAge() {
    var state = Self.state()
    state.content = .loaded(Self.detail(updatedMinutesAgo: 4))
    #expect(state.nowCard == .located(
      zone: "리벳 스테이지 앞 왼쪽",
      activity: "슬램",
      source: "기수가 4분 전에 알렸어요",
      isMuted: false
    ))

    state.content = .loaded(Self.detail(updatedMinutesAgo: 32))
    #expect(state.nowCard == .located(
      zone: "리벳 스테이지 앞 왼쪽",
      activity: "슬램",
      source: "32분 전 정보예요 · 지금은 다를 수 있어요",
      isMuted: true
    ))

    state.content = .loaded(Self.detail(
      status: .resting,
      activity: .resting,
      updatedMinutesAgo: 12
    ))
    #expect(state.nowCard == .located(
      zone: "리벳 스테이지 앞 왼쪽",
      activity: "쉬는 중",
      source: "기수가 12분 전에 알렸어요",
      isMuted: true
    ))

    state.content = .loaded(Self.detail(status: .ended))
    #expect(state.nowCard == .ended)
  }

  @Test("오늘 계획은 기수 순서를 지키고 팩에 없는 공연은 건너뛴다")
  func planRowsKeepBearerOrder() {
    var state = Self.state()
    state.content = .loaded(Self.detail(plan: ["set_late", "set_missing", "set_now", "set_past"]))

    #expect(state.planRows.map(\.id) == ["set_late", "set_now", "set_past"])
    #expect(state.planRows.map(\.timing) == [.upcoming, .now, .past])
    #expect(state.planRows.map(\.isMine) == [false, true, false])
    #expect(state.planRows.first?.time == "23:00")

    state.content = .loaded(Self.detail(
      status: .ended,
      plan: ["set_late", "set_now"]
    ))
    #expect(state.planRows.map(\.timing) == [.past, .past])
  }

  // MARK: - 도우미

  private struct FailureCase {
    let error: FestivalFlagDetailError
    let failure: FestivalFlagDetailFeature.State.Failure
  }

  private func makeStore(
    state: FestivalFlagDetailFeature.State = Self.state(),
    clock: TestClock<Duration> = TestClock(),
    detail: @escaping @Sendable (String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail = { _ in
      return FestivalFlagDetailFeatureTests.detail()
    },
    setFollowing: @escaping @Sendable (
      Bool,
      String
    ) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult = {
      _, _ throws(FestivalFlagFollowError) in
      throw .unavailable
    }
  ) -> TestStoreOf<FestivalFlagDetailFeature> {
    return TestStore(initialState: state) {
      FestivalFlagDetailFeature()
    } withDependencies: {
      $0.date.now = Self.now
      $0.continuousClock = clock
      $0.festivalFlagDetailUseCase = MockFestivalFlagDetailUseCase(detail: detail)
      $0.festivalFlagUseCase = MockFestivalFlagUseCase(setFollowing: setFollowing)
    }
  }

  private func makeLoadedStore(
    failing error: FestivalFlagFollowError,
    clock: TestClock<Duration> = TestClock()
  ) -> TestStoreOf<FestivalFlagDetailFeature> {
    var state = Self.state()
    state.content = .loaded(Self.detail())
    return makeStore(
      state: state,
      clock: clock,
      setFollowing: { _, _ throws(FestivalFlagFollowError) in throw error }
    )
  }

  private nonisolated static func state(hasSession: Bool = true) -> FestivalFlagDetailFeature.State {
    let performances: [String: FestivalFlagDetailContext.Performance] = [
      "set_past": .init(
        artist: "Sunset Riot",
        stageName: "MAIN 스테이지",
        startsAt: now.addingTimeInterval(-3 * 3_600),
        endsAt: now.addingTimeInterval(-2 * 3_600)
      ),
      "set_now": .init(
        artist: "The Lime Flags",
        stageName: "SUB 스테이지",
        startsAt: now.addingTimeInterval(-600),
        endsAt: now.addingTimeInterval(1_800)
      ),
      "set_late": .init(
        artist: "모쉬핏",
        stageName: "TENT 스테이지",
        startsAt: Date(timeIntervalSince1970: 1_794_060_000),
        endsAt: Date(timeIntervalSince1970: 1_794_063_600)
      ),
    ]
    return FestivalFlagDetailFeature.State(
      flagID: "flg_1",
      context: FestivalFlagDetailContext(
        zoneNames: ["zone_a": "리벳 스테이지 앞 왼쪽"],
        performances: performances,
        mySetIDs: ["set_now"],
        hasSession: hasSession
      ),
      now: now
    )
  }

  private nonisolated static func detail(
    status: FestivalFlagDetail.Status = .active,
    activity: FestivalFlagDetail.Activity? = .slam,
    updatedMinutesAgo: Double = 4,
    plan: [String] = ["set_past", "set_now", "set_late"]
  ) -> FestivalFlagDetail {
    return FestivalFlagDetail(
      id: "flg_1",
      name: "호락호락",
      thumbnailURL: nil,
      photoURL: nil,
      tags: ["slam", "sing", "newbie"],
      bio: "처음 와도 괜찮아요",
      followerCount: 1_284,
      isPlanVisible: true,
      planSetIDs: plan,
      homeZoneID: nil,
      status: status,
      zoneID: "zone_a",
      activity: activity,
      statusUpdatedAt: now.addingTimeInterval(-updatedMinutesAgo * 60),
      isFollowing: false,
      isBearer: false,
      isHidden: false
    )
  }
}
