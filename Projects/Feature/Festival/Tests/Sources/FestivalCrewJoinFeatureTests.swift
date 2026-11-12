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

  /// Figma S08 D: 이미 다른 크루에 있으면 확인 뒤 기존 크루를 나가고 참여한다.
  @Test func alreadyInCrewLeavesCurrentCrewThenJoins() async {
    let calls = LockIsolated<[String]>([])
    let store = TestStore(initialState: loadedState()) {
      FestivalCrewJoinFeature()
    } withDependencies: {
      $0.festivalLiveBoardUseCase = CurrentCrewBoard()
      $0.festivalCrewUseCase = AlreadyInCrewSpy(
        calls: calls,
        leaveError: nil
      )
    }
    await store.send(.view(.joinTapped)) { $0.isJoining = true }
    await store.receive(\.async.join)
    await store.receive(\.inner.joinFailed)
    await store.receive(\.async.findCurrentCrew)
    await store.receive(\.inner.currentCrewFound) {
      $0.isJoining = false
      $0.pendingLeave = .init(
        crewID: "crew_old",
        crewName: "락린이들"
      )
      $0.alert = .alert(
        title: "기존 크루에서 나갈까요?",
        message: "지금 \"락린이들\"에 있어요. 페스티벌마다 크루는 하나만 들 수 있어서, 나가야 펜타 크루에 들어갈 수 있어요.",
        confirmTitle: "나가고 참여하기",
        cancelTitle: "취소"
      )
    }
    await store.send(.alert(.presented(.confirmTapped))) {
      $0.alert = nil
      $0.pendingLeave = nil
      $0.isJoining = true
    }
    await store.receive(\.async.leaveAndJoin)
    await store.receive(\.inner.joined) { $0.isJoining = false }
    await store.receive(\.delegate.joined)
    #expect(calls.value == ["join", "leave:crew_old", "join"])
  }

  @Test func leaveFailureDoesNotJoin() async {
    let calls = LockIsolated<[String]>([])
    var initial = loadedState()
    initial.pendingLeave = .init(
      crewID: "crew_old",
      crewName: "락린이들"
    )
    initial.alert = .alert(title: "기존 크루에서 나갈까요?")
    let store = TestStore(initialState: initial) {
      FestivalCrewJoinFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = AlreadyInCrewSpy(
        calls: calls,
        leaveError: .forbidden
      )
    }
    await store.send(.alert(.presented(.confirmTapped))) {
      $0.alert = nil
      $0.pendingLeave = nil
      $0.isJoining = true
    }
    await store.receive(\.async.leaveAndJoin)
    await store.receive(\.inner.leaveFailed) {
      $0.isJoining = false
      $0.alert = .alert(
        title: "기존 크루에서 나가지 못했어요",
        message: "크루장은 크루장을 넘기거나 크루를 해산한 뒤 나갈 수 있어요.",
        confirmTitle: "확인",
        cancelTitle: "닫기"
      )
    }
    #expect(calls.value == ["leave:crew_old"])
  }

  @Test func cancelingLeaveConfirmKeepsCurrentCrew() async {
    var initial = loadedState()
    initial.pendingLeave = .init(
      crewID: "crew_old",
      crewName: "락린이들"
    )
    initial.alert = .alert(title: "기존 크루에서 나갈까요?")
    let store = TestStore(initialState: initial) {
      FestivalCrewJoinFeature()
    }
    await store.send(.alert(.presented(.cancelTapped))) {
      $0.alert = nil
      $0.pendingLeave = nil
    }
  }

  private func loadedState() -> FestivalCrewJoinFeature.State {
    var initial = FestivalCrewJoinFeature.State(
      code: "K7P2QX",
      hasSession: true
    )
    initial.invite = invite
    initial.load = .loaded
    return initial
  }
}

/// 처음 참여는 409(이미 다른 크루)로 막고, 나간 뒤 참여는 받아 준다.
private struct AlreadyInCrewSpy: FestivalCrewUseCaseInterface {
  let calls: LockIsolated<[String]>
  let leaveError: FestivalCrewError?

  func gather(
    crewID _: String,
    zoneID _: String
  ) async throws {
    Issue.record("gather는 이 테스트에서 부르지 않는다")
  }

  func create(
    festivalID _: String,
    name _: String,
    nickname _: String?
  ) async throws -> FestivalCrew {
    Issue.record("create는 이 테스트에서 부르지 않는다")
    throw FestivalCrewError.unavailable
  }

  func join(inviteCode _: String) async throws -> FestivalCrew {
    let left = calls.value.contains { $0.hasPrefix("leave:") }
    calls.withValue { $0.append("join") }
    guard left else { throw FestivalCrewError.alreadyInCrew }
    return FestivalCrew(
      id: "crew_a",
      festivalID: "fst_a",
      name: "펜타 크루",
      ownerID: "user_b",
      members: [],
      inviteCode: nil,
      inviteExpiresAt: nil
    )
  }

  func leave(crewID: String) async throws {
    calls.withValue { $0.append("leave:\(crewID)") }
    if let leaveError { throw leaveError }
  }
}

/// 초대받은 페스티벌에서 내가 들어 있는 크루를 돌려준다.
private struct CurrentCrewBoard: FestivalLiveBoardUseCaseInterface {
  func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    return FestivalLiveBoardSnapshot(
      festivalID: festivalID,
      activeFlags: [],
      followedFlags: [],
      crew: .init(
        id: "crew_old",
        name: "락린이들",
        members: []
      )
    )
  }
}
