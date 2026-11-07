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

  @Test("팔로우 결과를 반영하고 부모에 알리며, 대표 깃발을 서버 값으로 다시 받고 완료 토스트를 띄운다")
  func followSuccessUpdatesButtonAndCount() async {
    let calls = LockIsolated<[Bool]>([])
    let clock = TestClock()
    var state = Self.state()
    state.content = .loaded(Self.detail())
    let reloaded = Self.detail(
      followerCount: 1_285,
      isFollowing: true,
      isPinned: true
    )
    let store = makeStore(
      state: state,
      clock: clock,
      detail: { _ in return reloaded },
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
      $0.loadGeneration = 1
    }
    #expect(calls.value == [true])
    #expect(store.state.isFollowing)
    #expect(store.state.followerCount == 1_285)
    await store.receive(\.delegate.followChanged)
    await store.receive(\.async.load)
    await store.receive(\.async.showToast) {
      $0.toast = .followed(name: "호락호락")
    }
    await store.receive(\.inner.loaded) {
      $0.content = .loaded(reloaded)
      $0.lastLoadedAt = Self.now
      $0.followOverride = nil
    }
    #expect(store.state.isPinned)
    #expect(store.state.showsLockScreenToggle)
    await clock.advance(by: .seconds(2))
    await store.receive(\.inner.toastExpired) { $0.toast = nil }
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
    await limitStore.receive(\.async.showToast) { $0.toast = .followLimit }
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

  @Test("히어로 태그는 디렉토리와 같은 이름으로 보인다")
  func tagTitlesUseDirectoryNames() {
    var state = Self.state()
    #expect(state.tagTitles.isEmpty)

    state.content = .loaded(Self.detail())
    #expect(state.tagTitles == ["슬램", "떼창", "초보 환영"])
  }

  // MARK: - 잠금화면에 표시

  @Test("잠금화면 표시는 팔로잉일 때만 보이고 상세·라이브 보드의 대표 깃발을 따른다")
  func lockScreenToggleVisibilityAndState() {
    var state = Self.state()
    state.content = .loaded(Self.detail())
    #expect(!state.showsLockScreenToggle)

    state.content = .loaded(Self.detail(isFollowing: true))
    #expect(state.showsLockScreenToggle)
    #expect(!state.isPinned)

    // 상세에 대표 여부가 없으면 라이브 보드가 알려 준 대표 깃발을 쓴다.
    state.context.pinnedFlagID = "flg_1"
    #expect(state.isPinned)
    state.content = .loaded(Self.detail(
      isFollowing: true,
      isPinned: false
    ))
    #expect(!state.isPinned)

    var signedOut = Self.state(hasSession: false)
    signedOut.content = .loaded(Self.detail(isFollowing: true))
    #expect(!signedOut.showsLockScreenToggle)
  }

  @Test("토글을 켜면 바로 켜진 채 대표 깃발로 지정하고 서버 값으로 확정한다")
  func lockScreenToggleSetsPinnedFlag() async {
    let calls = LockIsolated<[String?]>([])
    var state = Self.state()
    state.content = .loaded(Self.detail(isFollowing: true))
    let store = makeStore(
      state: state,
      setPinnedFlag: { flagID throws(FestivalFlagPinError) in
        calls.withValue { $0.append(flagID) }
        return flagID
      }
    )

    await store.send(.view(.lockScreenToggled(true))) {
      $0.pin = .init(
        override: true,
        isPending: true
      )
    }
    #expect(store.state.isPinned)
    await store.receive(\.async.setPinned)
    await store.receive(\.inner.pinFinished) {
      $0.pin = .init(override: true)
    }

    await store.send(.view(.lockScreenToggled(false))) {
      $0.pin = .init(
        override: false,
        isPending: true
      )
    }
    await store.receive(\.async.setPinned)
    await store.receive(\.inner.pinFinished) {
      $0.pin = .init(override: false)
    }
    #expect(calls.value == ["flg_1", nil])
  }

  @Test("대표 깃발 지정이 실패하면 되돌리고 로그인·약관 요청이나 안내로 처리한다")
  func lockScreenToggleFailureReverts() async {
    let cases: [(FestivalFlagPinError, PinFailureRoute)] = [
      (
        .unavailable,
        .toast
      ),
      (
        .notFollowing,
        .toast
      ),
      (
        .loginRequired,
        .login
      ),
      (
        .termsRequired,
        .terms
      ),
    ]
    for item in cases {
      let error = item.0
      var state = Self.state()
      state.content = .loaded(Self.detail(isFollowing: true))
      let store = makeStore(
        state: state,
        setPinnedFlag: { _ throws(FestivalFlagPinError) in throw error }
      )
      store.exhaustivity = .off(showSkippedAssertions: false)

      await store.send(.view(.lockScreenToggled(true)))
      await store.receive(\.inner.pinFinished) {
        $0.pin = .init(override: false)
      }
      #expect(!store.state.isPinned)
      switch item.1 {
      case .toast:
        await store.receive(\.async.showToast) { $0.toast = .pinFailed }
      case .login:
        await store.receive(\.delegate.reportLoginRequested)
      case .terms:
        await store.receive(\.delegate.termsAcceptanceRequested)
      }
    }
  }

  @Test("팔로잉이 아니거나 오프라인·요청 중이면 토글을 무시한다")
  func lockScreenToggleIgnoredWhenUnavailable() async {
    var notFollowing = Self.state()
    notFollowing.content = .loaded(Self.detail())
    await makeStore(state: notFollowing).send(.view(.lockScreenToggled(true)))

    var offline = Self.state()
    offline.content = .loaded(Self.detail(isFollowing: true))
    offline.isOffline = true
    await makeStore(state: offline).send(.view(.lockScreenToggled(true)))

    var pending = Self.state()
    pending.content = .loaded(Self.detail(isFollowing: true))
    pending.pin = .init(
      override: true,
      isPending: true
    )
    await makeStore(state: pending).send(.view(.lockScreenToggled(false)))
  }

  // MARK: - 신고

  @Test("로그인하지 않았으면 신고 대신 로그인을 요청한다")
  func reportWithoutSessionRequestsLogin() async {
    var state = Self.state(hasSession: false)
    state.content = .loaded(Self.detail())
    let store = makeStore(state: state)

    await store.send(.view(.reportTapped))
    await store.receive(\.delegate.reportLoginRequested)
  }

  @Test("사유를 골라 신고하면 시트를 닫고 접수 결과를 알린다")
  func reportSubmitsReason() async {
    let calls = LockIsolated<[FestivalFlagReportReason]>([])
    let clock = TestClock()
    var state = Self.state()
    state.content = .loaded(Self.detail())
    let store = makeStore(
      state: state,
      clock: clock,
      report: { _, reason throws(FestivalFlagReportError) in
        calls.withValue { $0.append(reason) }
      }
    )

    await store.send(.view(.reportTapped)) {
      $0.destination = .report(FestivalFlagReportFeature.State())
    }
    // 사유를 고르기 전에는 신고하지 않는다.
    await store.send(.destination(.presented(.report(.view(.submitTapped)))))
    await store.send(.destination(.presented(.report(.view(.reasonSelected(.inappropriate)))))) {
      $0.destination = .report(FestivalFlagReportFeature.State(selectedReason: .inappropriate))
    }
    await store.send(.destination(.presented(.report(.view(.submitTapped)))))
    await store.receive(\.destination.presented.report.delegate.submitted) {
      $0.destination = nil
      $0.isReportPending = true
    }
    await store.receive(\.async.report)
    await store.receive(\.inner.reported) {
      $0.isReportPending = false
    }
    await store.receive(\.async.showToast) { $0.toast = .reported }
    #expect(calls.value == [.inappropriate])
    await clock.advance(by: .seconds(2))
    await store.receive(\.inner.toastExpired) { $0.toast = nil }
  }

  @Test("신고 실패는 중복·로그인·약관·일시 오류로 나눠 처리한다")
  func reportFailuresAreRouted() async {
    let cases: [(FestivalFlagReportError, ReportFailureRoute)] = [
      (
        .alreadyReported,
        .toast(.alreadyReported)
      ),
      (
        .unavailable,
        .toast(.reportFailed)
      ),
      (
        .notFound,
        .toast(.reportFailed)
      ),
      (
        .loginRequired,
        .login
      ),
      (
        .termsRequired,
        .terms
      ),
    ]
    for item in cases {
      let error = item.0
      var state = Self.state()
      state.content = .loaded(Self.detail())
      state.isReportPending = true
      let store = makeStore(
        state: state,
        report: { _, _ throws(FestivalFlagReportError) in throw error }
      )
      store.exhaustivity = .off(showSkippedAssertions: false)

      await store.send(.async(.report(.fake)))
      await store.receive(\.inner.reportFailed) { $0.isReportPending = false }
      switch item.1 {
      case let .toast(toast):
        await store.receive(\.async.showToast) { $0.toast = toast }
      case .login:
        await store.receive(\.delegate.reportLoginRequested)
      case .terms:
        await store.receive(\.delegate.termsAcceptanceRequested)
      }
    }
  }

  @Test("화면을 떠나면 신고·대표 요청을 멈추고 늦은 결과는 버린다")
  func leavingCancelsReportAndPin() async {
    var state = Self.state()
    state.content = .loaded(Self.detail(isFollowing: true))
    state.isReportPending = true
    state.pin = .init(
      override: true,
      isPending: true
    )
    let store = makeStore(state: state)

    await store.send(.view(.onDisappear)) {
      $0.loadGeneration = 1
      $0.isReportPending = false
      $0.pin = .init()
    }
    await store.send(.inner(.reportFailed(.loginRequired)))
    await store.send(.inner(.pinFinished(
      requested: true,
      .failure(.loginRequired)
    )))
  }

  // MARK: - 문맥 변경

  @Test("같은 계정의 문맥 변경은 다시 불러오지 않는다")
  func sameAccountContextChangeKeepsDetail() async {
    var state = Self.state()
    state.content = .loaded(Self.detail(isFollowing: true))
    let store = makeStore(state: state)
    var context = state.context
    context.mySetIDs = []
    context.zoneNames = [:]

    await store.send(.view(.contextChanged(context))) {
      $0.context = context
    }
  }

  @Test("다른 계정으로 바뀌면 계정별 값을 비우고 다시 불러온다")
  func accountChangeReloadsDetail() async {
    var state = Self.state()
    state.content = .loaded(Self.detail(isFollowing: true))
    state.followOverride = .init(
      isFollowing: true,
      followerCount: 1_285
    )
    state.pin = .init(override: true)
    state.destination = .report(FestivalFlagReportFeature.State())
    let fresh = Self.detail(isFollowing: false)
    let store = makeStore(
      state: state,
      detail: { _ in return fresh }
    )
    // 다른 값은 같고 계정만 바뀐 문맥(A → B)
    var context = state.context
    context.accountID = "user-b"

    await store.send(.view(.contextChanged(context))) {
      $0.context = context
      $0.followOverride = nil
      $0.pin = .init()
      $0.destination = nil
      $0.content = .loading
      $0.loadGeneration = 1
    }
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.content = .loaded(fresh)
      $0.lastLoadedAt = Self.now
    }
    #expect(!store.state.isFollowing)
  }

  @Test("공유 링크는 깃발 딥링크다")
  func shareURLUsesFlagDeeplink() {
    #expect(Self.state().shareURL.absoluteString == "festicore://flag/flg_1")
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

  private enum PinFailureRoute {
    case toast
    case login
    case terms
  }

  private enum ReportFailureRoute {
    case toast(FestivalFlagDetailFeature.State.Toast)
    case login
    case terms
  }

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
    },
    report: @escaping @Sendable (
      String,
      FestivalFlagReportReason
    ) async throws(FestivalFlagReportError) -> Void = {
      _, _ throws(FestivalFlagReportError) in
      throw .unavailable
    },
    setPinnedFlag: @escaping @Sendable (String?) async throws(FestivalFlagPinError) -> String? = {
      _ throws(FestivalFlagPinError) in
      throw .unavailable
    }
  ) -> TestStoreOf<FestivalFlagDetailFeature> {
    return TestStore(initialState: state) {
      FestivalFlagDetailFeature()
    } withDependencies: {
      $0.date.now = Self.now
      $0.continuousClock = clock
      $0.festivalFlagDetailUseCase = MockFestivalFlagDetailUseCase(
        detail: detail,
        report: report,
        setPinnedFlag: setPinnedFlag
      )
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

  private nonisolated static func state(
    hasSession: Bool = true,
    accountID: String? = "user-a"
  ) -> FestivalFlagDetailFeature.State {
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
        hasSession: hasSession,
        accountID: hasSession ? accountID : nil
      ),
      now: now
    )
  }

  private nonisolated static func detail(
    status: FestivalFlagDetail.Status = .active,
    activity: FestivalFlagDetail.Activity? = .slam,
    updatedMinutesAgo: Double = 4,
    plan: [String] = ["set_past", "set_now", "set_late"],
    followerCount: Int = 1_284,
    isFollowing: Bool = false,
    isPinned: Bool? = nil
  ) -> FestivalFlagDetail {
    return FestivalFlagDetail(
      id: "flg_1",
      name: "호락호락",
      thumbnailURL: nil,
      photoURL: nil,
      tags: ["slam", "sing", "newbie"],
      bio: "처음 와도 괜찮아요",
      followerCount: followerCount,
      isPlanVisible: true,
      planSetIDs: plan,
      homeZoneID: nil,
      status: status,
      zoneID: "zone_a",
      activity: activity,
      statusUpdatedAt: now.addingTimeInterval(-updatedMinutesAgo * 60),
      isFollowing: isFollowing,
      isBearer: false,
      isPinned: isPinned,
      isHidden: false
    )
  }
}
