//
//  ProfileFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import BearerDomainInterface
import ComposableArchitecture
import FestiCoreAnalyticsInterface
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import Testing
@testable import Profile

@MainActor
struct ProfileFeatureTests {
  @Test func appearLoadsLocalPacksThenRefreshesUpdates() async {
    let local = [FestivalReceivedPack(id: "fst_a", name: "원더리벳 2026", packVersion: 12, latestPackVersion: 12)]
    let refreshed = [FestivalReceivedPack(id: "fst_a", name: "원더리벳 2026", packVersion: 12, latestPackVersion: 13)]
    let analytics = LockIsolated<[AnalyticsEvent]>([])
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { event in analytics.withValue { $0.append(event) } }
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { local },
        refreshReceivedPacks: { refreshed }
      )
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(packChanges: { festivalID, fromVersion in
        #expect(festivalID == "fst_a")
        #expect(fromVersion == 12)
        return FestivalPackChanges(
          fromVersion: 12,
          toVersion: 13,
          sizeBytes: 1_024,
          changedSets: 2
        )
      })
    }

    await store.send(.view(.onAppear)) { $0.packLoad = .loading }
    #expect(analytics.value == [.screenView(
      screen: .profile,
      referrer: nil
    )])
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsLoaded) {
      $0.packs = local
      $0.packLoad = .loaded
    }
    await store.receive(\.inner.packsRefreshed) { $0.packs = refreshed }
    #expect(store.state.packs.first?.hasUpdate == true)
    // 새 버전이 있는 팩은 내 버전 기준 바뀐 공연 수를 읽는다(시안 "시간표 N개 변경").
    await store.receive(\.async.fetchPackChanges)
    await store.receive(\.inner.packChangesLoaded) {
      $0.packChangedSets["fst_a"] = 2
    }
  }

  @Test func packChangesFailureKeepsVersionText() async {
    let refreshed = [
      FestivalReceivedPack(
        id: "fst_a",
        name: "원더리벳 2026",
        packVersion: 12,
        latestPackVersion: 13
      )
    ]
    var state = ProfileFeature.State()
    state.packLoad = .loaded
    let store = TestStore(initialState: state) {
      ProfileFeature()
    } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(packChanges: { _, _ in
        throw URLError(.notConnectedToInternet)
      })
    }

    await store.send(.inner(.packsRefreshed(refreshed))) { $0.packs = refreshed }
    await store.receive(\.async.fetchPackChanges)
    #expect(store.state.packChangedSets.isEmpty)
  }

  @Test func refreshFailureKeepsLocalPacks() async {
    let local = [FestivalReceivedPack(id: "fst_a", name: "A", packVersion: 1)]
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { local },
        refreshReceivedPacks: { throw URLError(.notConnectedToInternet) }
      )
    }

    await store.send(.view(.onAppear)) { $0.packLoad = .loading }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsLoaded) {
      $0.packs = local
      $0.packLoad = .loaded
    }
  }

  @Test func localPackFailureShowsRetry() async {
    let attempts = LockIsolated(0)
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: {
          attempts.withValue { $0 += 1 }
          if attempts.value == 1 { throw URLError(.cannotOpenFile) }
          return []
        },
        refreshReceivedPacks: { [] }
      )
    }

    await store.send(.view(.onAppear)) { $0.packLoad = .loading }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsFailed) { $0.packLoad = .failed }
    await store.send(.view(.packsRetryTapped)) { $0.packLoad = .loading }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsLoaded) { $0.packLoad = .loaded }
    await store.receive(\.inner.packsRefreshed)
  }

  @Test func reappearKeepsShownPacksWhileReloading() async {
    var state = ProfileFeature.State()
    state.packs = [FestivalReceivedPack(id: "fst_a", name: "A", packVersion: 1)]
    state.packLoad = .loaded
    let store = TestStore(initialState: state) {
      ProfileFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { throw URLError(.cannotOpenFile) },
        refreshReceivedPacks: { [] }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsFailed)
  }

  @Test("로그아웃 상태의 마이(More B)는 로그인 카드만 두고 기수 카드를 숨긴다")
  func guestHidesBearerPrompt() {
    #expect(!ProfileFeature.State().showsBearerPrompt)
    #expect(signedInState().showsBearerPrompt)
  }

  @Test("받은 팩이 없을 때 '페스티벌 둘러보기'는 페스티벌 목록을 요청한다")
  func browseFestivalsRequestsFestivalList() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.browseFestivalsTapped))
    await store.receive(\.delegate.festivalListRequested)
  }

  @Test("로그인 유도 카드는 로그인하지 않았을 때만 보이고 계정 상태를 확인하는 동안에는 숨긴다")
  func loginPromptShowsOnlyForGuest() {
    #expect(ProfileFeature.State().showsLoginPrompt)
    #expect(!signedInState().showsLoginPrompt)

    var loading = ProfileFeature.State()
    loading.isLoading = true
    #expect(!loading.showsLoginPrompt)
  }

  @Test("비로그인 마이의 로그인 카드는 로그인 시트를 요청한다")
  func guestLoginPromptRequestsLogin() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.loginTapped))
    await store.receive(\.delegate.loginRequested)
  }

  @Test("로그인 카드의 Apple·Google 버튼은 고른 제공자로 로그인을 요청한다")
  func guestSocialLoginRequestsProvider() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.socialLoginTapped(.apple)))
    await store.receive(\.delegate.socialLoginRequested)
    await store.send(.view(.socialLoginTapped(.google)))
    await store.receive(\.delegate.socialLoginRequested)
  }

  @Test func packTapOpensPackDetailAndDeletionReloadsPacks() async {
    var state = ProfileFeature.State()
    state.packs = [FestivalReceivedPack(id: "fst_a", name: "원더리벳 2026", packVersion: 12)]
    state.packLoad = .loaded
    let store = TestStore(initialState: state) {
      ProfileFeature()
    } withDependencies: {
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { [] },
        refreshReceivedPacks: { [] }
      )
    }

    await store.send(.view(.packTapped("fst_unknown")))
    await store.send(.view(.packTapped("fst_a"))) {
      $0.destination = .packDetail(.init(festivalID: "fst_a", title: "원더리벳 2026"))
    }
    await store.send(.destination(.presented(.packDetail(.delegate(.packDeleted))))) {
      $0.destination = nil
    }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsLoaded) { $0.packs = [] }
    await store.receive(\.inner.packsRefreshed)
  }

  @Test("설정 버튼은 현재 계정 상태로 설정 홈을 열고 뒤로 가면 마이로 돌아온다")
  func settingsTapOpensSettingsHome() async {
    let store = TestStore(initialState: signedInState()) { ProfileFeature() }

    await store.send(.view(.settingsTapped)) {
      $0.destination = .settings(.init(hasSession: true))
    }
    await store.send(.destination(.presented(.settings(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  @Test("설정 홈이 열려 있으면 계정 상태 변경을 설정 홈으로 전달한다")
  func accountChangesAreForwardedToSettingsHome() async {
    var state = signedInState()
    state.destination = .settings(.init(hasSession: true))
    let store = TestStore(initialState: state) { ProfileFeature() }

    await store.send(.view(.accountChanged(
      profile: nil,
      hasSession: true,
      isLoading: true,
      message: nil
    ))) {
      $0.isLoading = true
    }
    await store.receive(\.destination.presented.settings.view.accountChanged) {
      $0.destination = .settings(.init(
        hasSession: true,
        isLoading: true
      ))
    }
  }

  @Test("계정 화면에서 로그아웃되면 설정 홈째로 닫고 마이로 돌아온다")
  func losingSessionOnAccountScreenClosesSettingsHome() async {
    var settings = SettingsHomeFeature.State(hasSession: true)
    settings.destination = .account(.init(profile: nil))
    var state = signedInState()
    state.destination = .settings(settings)
    let store = TestStore(initialState: state) { ProfileFeature() }

    await store.send(.view(.accountChanged(
      profile: nil,
      hasSession: false,
      isLoading: false,
      message: nil
    ))) {
      $0.hasSession = false
      $0.destination = nil
    }
  }

  @Test("설정 홈의 계정 요청은 마이 delegate로 앱에 전달한다")
  func settingsAccountRequestsAreForwardedToApp() async {
    let user = AuthUser(
      id: "user-a",
      provider: "apple",
      email: nil,
      nickname: "새이름",
      nicknameConfirmed: true,
      termsAcceptedAt: "2026-10-01",
      termsVersion: "2026-10",
      pushOptIn: false,
      profileImageURL: nil
    )
    var state = signedInState()
    state.destination = .settings(.init(hasSession: true))
    let store = TestStore(initialState: state) { ProfileFeature() }

    await store.send(.destination(.presented(.settings(.delegate(.logoutRequested)))))
    await store.receive(\.delegate.logoutRequested)
    await store.send(.destination(.presented(.settings(.delegate(.withdrawRequested)))))
    await store.receive(\.delegate.withdrawRequested)
    await store.send(.destination(.presented(.settings(.delegate(.profileRefreshRequested)))))
    await store.receive(\.delegate.profileRefreshRequested)
    await store.send(.destination(.presented(.settings(.delegate(.profileUpdated(user))))))
    await store.receive(\.delegate.profileUpdated)
  }

  @Test("알림 설정이 열린 채 설정 홈째로 닫혀도 남은 변경을 보낸다")
  func dismissingSettingsHomeStillSendsUnsavedNotificationChanges() async {
    let sent = LockIsolated<[[NotificationSettingsFeature.Kind: Bool]]>([])
    var notifications = NotificationSettingsFeature.State()
    notifications.settings = FestivalNotificationSettings(
      flagStatus: false,
      crewStatus: false
    )
    notifications.pendingChanges = [.crewStatus: false]
    var settings = SettingsHomeFeature.State()
    settings.destination = .notifications(notifications)
    var state = ProfileFeature.State()
    state.destination = .settings(settings)
    let store = TestStore(initialState: state) {
      ProfileFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        updateSettings: { changes in
          sent.withValue { $0.append(changes) }
          return FestivalNotificationSettings(
            flagStatus: false,
            crewStatus: false
          )
        }
      )
    }

    await store.send(.destination(.dismiss)) { $0.destination = nil }
    await store.finish()
    #expect(sent.value == [[.crewStatus: false]])
  }

  @Test("로그인했으면 기수 깃발을 읽고, 있으면 기수 카드 대신 내 깃발 카드(More D)를 보인다")
  func loadsMyFlag() async {
    var state = signedInState()
    state.packLoad = .loading
    state.packs = [FestivalReceivedPack(
      id: "fst_1",
      name: "원더리벳 2026",
      packVersion: 1
    )]
    let flag = BearerOwnedFlag(
      festivalID: "fst_1",
      isOwner: true,
      joinedAt: nil,
      profile: BearerFlagProfile(
        id: "flg_1",
        name: "호락호락",
        followerCount: 128
      ),
      lifecycle: .scheduled,
      isHidden: false
    )
    let hidden = BearerOwnedFlag(
      festivalID: "fst_2",
      isOwner: false,
      joinedAt: nil,
      profile: BearerFlagProfile(
        id: "flg_2",
        name: "숨김"
      ),
      lifecycle: nil,
      isHidden: true
    )
    let store = TestStore(initialState: state) {
      ProfileFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { _ in }
      $0.bearerUseCase = ProfileBearerUseCase(flags: { festivalID in
        #expect(festivalID == nil)
        return [hidden, flag]
      })
    }
    #expect(store.state.showsBearerPrompt)

    await store.send(.view(.onAppear)) { $0.bearerFlags = .loading }
    await store.receive(\.async.fetchBearerFlags)
    await store.receive(\.inner.bearerFlagsLoaded) { $0.bearerFlags = .loaded([flag]) }
    #expect(!store.state.showsBearerPrompt)
    #expect(store.state.myFlagMeta == "원더리벳 2026 · 팔로워 128 · 예정")

    await store.send(.view(.myFlagTapped))
    await store.receive(\.delegate.bearerProfileRequested)
    await store.send(.view(.bearerBoardTapped))
    await store.receive(\.delegate.bearerBoardRequested)
    await store.send(.view(.otherFestivalFlagTapped))
    await store.receive(\.delegate.bearerRequested)
  }

  @Test("기수 깃발을 읽지 못하면 기수 카드를 그대로 두고, 로그아웃하면 지운다")
  func myFlagFailureKeepsPrompt() async {
    var state = signedInState()
    state.packLoad = .loading
    let store = TestStore(initialState: state) {
      ProfileFeature()
    } withDependencies: {
      $0.bearerUseCase = ProfileBearerUseCase(flags: { _ in throw BearerError.offline })
    }

    await store.send(.view(.bearerFlagsRefreshRequested)) { $0.bearerFlags = .loading }
    await store.receive(\.async.fetchBearerFlags)
    await store.receive(\.inner.bearerFlagsFailed) { $0.bearerFlags = .failed }
    #expect(store.state.showsBearerPrompt)

    await store.send(.view(.accountChanged(
      profile: nil,
      hasSession: false,
      isLoading: false,
      message: nil
    ))) {
      $0.hasSession = false
      $0.bearerFlags = .idle
    }
  }

  @Test("로그인하지 않았으면 기수 깃발을 읽지 않는다")
  func guestSkipsMyFlag() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }
    await store.send(.view(.bearerFlagsRefreshRequested))
  }

  private func signedInState() -> ProfileFeature.State {
    var state = ProfileFeature.State()
    state.hasSession = true
    return state
  }
}

/// 마이·잠금화면 설정이 쓰는 기수 깃발·대표 깃발·팔로우 조회만 채운 대역. 다른 호출은 기본 Mock처럼 테스트 이슈다.
struct ProfileBearerUseCase: BearerUseCaseInterface {
  var flags: @Sendable (String?) async throws -> [BearerOwnedFlag] = { try await MockBearerUseCase().fetchBearerFlags(festivalID: $0) }
  var pinnedFlag: @Sendable () async throws -> BearerPinnedFlag? = { try await MockBearerUseCase().fetchPinnedFlag() }
  var followedFlags: @Sendable (String?) async throws -> [BearerFollowedFlag] = {
    try await MockBearerUseCase().fetchFollowedFlags(festivalID: $0)
  }
  let unregistered = MockBearerUseCase()

  func fetchBearerFlags(festivalID: String?) async throws -> [BearerOwnedFlag] {
    return try await flags(festivalID)
  }

  func makeRegisterRequest(
    festivalID: String,
    change: BearerProfileChange
  ) -> BearerRegisterRequest {
    return unregistered.makeRegisterRequest(
      festivalID: festivalID,
      change: change
    )
  }
  func register(_ request: BearerRegisterRequest) async throws -> BearerClaim { return try await unregistered.register(request) }
  func fetchPinnedFlag() async throws -> BearerPinnedFlag? { return try await pinnedFlag() }
  func fetchFollowedFlags(festivalID: String?) async throws -> [BearerFollowedFlag] { return try await followedFlags(festivalID) }
  func claim(
    festivalID: String,
    code: String
  ) async throws -> BearerClaim {
    return try await unregistered.claim(
      festivalID: festivalID,
      code: code
    )
  }
  func fetchFestival(festivalID: String) async throws -> BearerFestival {
    return try await unregistered.fetchFestival(festivalID: festivalID)
  }
  func fetchBoard(flagID: String) async throws -> BearerBoard { return try await unregistered.fetchBoard(flagID: flagID) }
  func updateProfile(
    flagID: String,
    change: BearerProfileChange
  ) async throws -> BearerFlagProfile {
    return try await unregistered.updateProfile(
      flagID: flagID,
      change: change
    )
  }
  func uploadPhoto(
    flagID: String,
    imageData: Data
  ) -> AsyncThrowingStream<BearerPhotoUploadEvent, Error> {
    return unregistered.uploadPhoto(
      flagID: flagID,
      imageData: imageData
    )
  }
  func makeStatusRequest(_ change: BearerStatusChange) -> BearerStatusRequest { return unregistered.makeStatusRequest(change) }
  func sendStatus(
    flagID: String,
    request: BearerStatusRequest
  ) async throws -> BearerFlagStatus {
    return try await unregistered.sendStatus(
      flagID: flagID,
      request: request
    )
  }
  func enqueueStatus(
    flagID: String,
    ownerUserID: String,
    request: BearerStatusRequest
  ) async {
    await unregistered.enqueueStatus(
      flagID: flagID,
      ownerUserID: ownerUserID,
      request: request
    )
  }
  func pendingStatus(flagID: String) async -> [BearerStatusRequest] { return await unregistered.pendingStatus(flagID: flagID) }
  func statusEvents(flagID: String) async -> AsyncStream<BearerOutboxEvent> { return await unregistered.statusEvents(flagID: flagID) }
  func retryPendingStatus() async { await unregistered.retryPendingStatus() }
  func inviteCoBearer(flagID: String) async throws -> BearerInvite { return try await unregistered.inviteCoBearer(flagID: flagID) }
  func removeCoBearer(
    flagID: String,
    userID: String
  ) async throws {
    try await unregistered.removeCoBearer(
      flagID: flagID,
      userID: userID
    )
  }
}
