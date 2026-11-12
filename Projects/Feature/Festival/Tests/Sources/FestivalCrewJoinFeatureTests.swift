import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalCrewJoinFeatureTests {
  private let invite = FestivalCrewInvite(
    code: "K7P2QX",
    crewName: "펜타 크루",
    festivalID: "fst_a",
    festivalName: "펜타포트",
    inviterNickname: "민지",
    memberCount: 4,
    expiresAt: Date(timeIntervalSince1970: 0)
  )

  @Test func loadsInviteAndAsksLoginBeforeJoining() async {
    let store = TestStore(initialState: FestivalCrewJoinFeature.State(
      code: "K7P2QX",
      hasSession: false
    )) {
      FestivalCrewJoinFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewSpy(invite: invite)
    }
    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.invite = self.invite
      $0.load = .loaded
    }
    await store.send(.view(.joinTapped))
    await store.receive(\.delegate.loginRequested)
  }

  @Test func joinsAndOpensCrew() async {
    var initial = FestivalCrewJoinFeature.State(
      code: "K7P2QX",
      hasSession: true
    )
    initial.invite = invite
    initial.load = .loaded
    let joined = FestivalCrew(
      id: "crew_a",
      festivalID: "fst_a",
      name: "펜타 크루",
      ownerID: "user_b",
      members: [],
      inviteCode: nil,
      inviteExpiresAt: nil
    )
    let store = TestStore(initialState: initial) {
      FestivalCrewJoinFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewSpy(join: joined)
    }
    await store.send(.view(.joinTapped)) { $0.isJoining = true }
    await store.receive(\.async.join)
    await store.receive(\.inner.joined) { $0.isJoining = false }
    await store.receive(\.delegate.joined)
  }

  @Test func fullCrewShowsAlert() async {
    var initial = FestivalCrewJoinFeature.State(
      code: "K7P2QX",
      hasSession: true
    )
    initial.invite = invite
    initial.load = .loaded
    let store = TestStore(initialState: initial) {
      FestivalCrewJoinFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewSpy(joinError: .full)
    }
    await store.send(.view(.joinTapped)) { $0.isJoining = true }
    await store.receive(\.async.join)
    await store.receive(\.inner.joinFailed) {
      $0.isJoining = false
      $0.alert = .alert(
        title: "크루에 참여하지 못했어요",
        message: "크루 정원 12명이 모두 찼어요.",
        confirmTitle: "확인",
        cancelTitle: "닫기"
      )
    }
  }

  @Test func expiredInviteShowsUnavailable() async {
    let store = TestStore(initialState: FestivalCrewJoinFeature.State(
      code: "K7P2QX",
      hasSession: true
    )) {
      FestivalCrewJoinFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewSpy(inviteError: .notFound)
    }
    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.receive(\.inner.loadFailed) { $0.load = .unavailable }
  }

  /// Figma S08 B·C: 만료된 초대와 정원이 찬 크루는 참여 대신 닫기만 둔다.
  @Test func blockerFollowsExpiryAndCapacity() {
    var state = FestivalCrewJoinFeature.State(
      code: "K7P2QX",
      hasSession: true
    )
    #expect(state.blocker(now: Date(timeIntervalSince1970: 0)) == nil)
    state.invite = invite
    #expect(state.blocker(now: Date(timeIntervalSince1970: -60)) == nil)
    #expect(state.blocker(now: Date(timeIntervalSince1970: 0)) == .expired)
    state.invite = FestivalCrewInvite(
      code: "K7P2QX",
      crewName: "펜타 크루",
      festivalID: "fst_a",
      festivalName: "펜타포트",
      inviterNickname: "민지",
      memberCount: FestivalCrew.maxMembers,
      expiresAt: Date(timeIntervalSince1970: 0)
    )
    #expect(state.blocker(now: Date(timeIntervalSince1970: -60)) == .full)
  }
}
