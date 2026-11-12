import ComposableArchitecture
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalCrewFeatureTests {
  private let now = Date(timeIntervalSince1970: 1_000_000)

  @Test func loadsDetailAndReplacesBoardMembers() async {
    let crew = crew(state: "eating")
    let store = TestStore(initialState: state(memberState: "here")) {
      FestivalCrewFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewSpy(detail: crew)
    }
    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.crew = crew
      $0.live = crew.live
      $0.load = .loaded
    }
  }

  @Test func myStateUpdatesImmediatelyAndSendsCurrentZone() async {
    let sent = LockIsolated<[String]>([])
    var initial = state(memberState: "here")
    initial.crew = crew(state: "here")
    let store = TestStore(initialState: initial) {
      FestivalCrewFeature()
    } withDependencies: {
      $0.date.now = now
      $0.festivalCrewUseCase = CrewSpy(status: { state, zone in
        sent.withValue { $0.append("\(state.rawValue)/\(zone ?? "-")") }
      })
    }
    await store.send(.view(.stateTapped(.eating))) {
      $0.live = self.live(
        state: "eating",
        zoneID: "zone_a",
        updatedAt: self.now
      )
      $0.isSendingStatus = true
    }
    await store.receive(\.async.updateStatus)
    await store.receive(\.inner.statusUpdated) { $0.isSendingStatus = false }
    #expect(sent.value == ["eating/zone_a"])
  }

  @Test func failedStatusShowsToastAndReloadsServerValue() async {
    let clock = TestClock()
    let serverCrew = crew(state: "here")
    var initial = state(memberState: "here")
    initial.crew = serverCrew
    let store = TestStore(initialState: initial) {
      FestivalCrewFeature()
    } withDependencies: {
      $0.date.now = now
      $0.continuousClock = clock
      $0.festivalCrewUseCase = CrewSpy(
        detail: serverCrew,
        status: { _, _ in throw FestivalCrewError.unavailable }
      )
    }
    await store.send(.view(.stateTapped(.leaving))) {
      $0.live = self.live(
        state: "leaving",
        zoneID: nil,
        updatedAt: self.now
      )
      $0.isSendingStatus = true
    }
    await store.receive(\.async.updateStatus)
    await store.receive(\.inner.statusFailed) {
      $0.isSendingStatus = false
      $0.toast = .statusFailed
    }
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.live = serverCrew.live
      $0.load = .loaded
    }
    await clock.advance(by: FestivalCrewFeature.toastDuration)
    await store.receive(\.inner.toastExpired) { $0.toast = nil }
  }

  @Test func onlyLeaderOpensMenu() async {
    var member = state(memberState: "here")
    member.crew = crew(
      state: "here",
      ownerID: "user_b"
    )
    let store = TestStore(initialState: member) { FestivalCrewFeature() }
    await store.send(.view(.menuTapped))
  }

  @Test func dissolveAsksConfirmationThenClosesCrew() async {
    let dissolved = LockIsolated(false)
    var initial = state(memberState: "here")
    initial.crew = crew(state: "here")
    let store = TestStore(initialState: initial) {
      FestivalCrewFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewSpy(dissolve: { dissolved.setValue(true) })
    }
    await store.send(.view(.menuTapped)) {
      $0.destination = .menu(FestivalCrewMenuFeature.State(
        crewName: "펜타 크루",
        members: []
      ))
    }
    await store.send(\.destination.menu.view.dissolveTapped)
    await store.receive(\.destination.menu.delegate.dissolve) {
      $0.pendingConfirm = .dissolve
      $0.destination = .confirm(.alert(
        title: "크루를 해산할까요?",
        message: "모든 크루원이 크루에서 나가요. 해산한 크루는 되돌릴 수 없어요.",
        confirmTitle: "해산하기"
      ))
    }
    await store.send(\.destination.confirm.confirmTapped) {
      $0.pendingConfirm = nil
      $0.destination = nil
    }
    await store.receive(\.async.dissolve)
    await store.receive(\.inner.dissolved)
    await store.receive(\.delegate.crewClosed)
    #expect(dissolved.value)
  }

  @Test func cooldownKeepsGatherClosed() async {
    var initial = state(memberState: "here")
    initial.live = FestivalLiveBoardSnapshot.Crew(
      id: "crew_a",
      name: "펜타 크루",
      members: initial.live?.members ?? [],
      ownerID: "user_a",
      gatherAvailableAt: now.addingTimeInterval(60)
    )
    let store = TestStore(initialState: initial) {
      FestivalCrewFeature()
    } withDependencies: {
      $0.date.now = now
    }
    await store.send(.view(.gatherTapped))
    let presentation = FestivalCrewPresentation(
      crew: store.state,
      now: now
    )
    #expect(presentation.gatherTitle == "모여! · 1분 뒤 다시 가능")
    #expect(!presentation.canGather)
  }

  @Test func presentationShowsGatherNoticeAndInactiveMember() {
    var initial = state(memberState: "leaving")
    initial.live = FestivalLiveBoardSnapshot.Crew(
      id: "crew_a",
      name: "펜타 크루",
      members: initial.live?.members ?? [],
      ownerID: "user_a",
      gatherRequest: .init(
        zoneID: "zone_a",
        byUserID: "user_a",
        at: now.addingTimeInterval(-120)
      )
    )
    let presentation = FestivalCrewPresentation(
      crew: initial,
      now: now
    )
    #expect(presentation.gatherNotice == "민지님이 \"슬램 존으로 모여\"를 보냈어요 · 2분 전")
    #expect(presentation.members.first?.isInactive == true)
    #expect(presentation.summary == "1명 · 1/2(금) 09:00까지 유지")
  }

  /// Figma S07 I: 끝난 크루는 끝난 날과 마지막 시각을 보이고, 내 줄에는 "나" 태그를 붙인다.
  @Test func presentationShowsArchivedCrewAndMe() {
    var initial = state(memberState: "here")
    initial.crew = FestivalCrew(
      id: "crew_a",
      festivalID: "fst_a",
      name: "펜타 크루",
      ownerID: "user_a",
      members: [],
      inviteCode: nil,
      inviteExpiresAt: nil,
      archivedAt: now
    )
    let presentation = FestivalCrewPresentation(
      crew: initial,
      now: now
    )
    #expect(presentation.isArchived)
    #expect(presentation.memberCount == "1 / \(FestivalCrew.maxMembers)")
    #expect(presentation.summary == "1명 · \(now.formatted(.festivalDay))에 끝남")
    #expect(presentation.members.first?.time == now.addingTimeInterval(-60).formatted(.monthDayTime))
    #expect(presentation.members.first?.isMe == true)
  }

  private func state(memberState: String) -> FestivalCrewFeature.State {
    let festival = try? JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"fst_a","days":[{"endsAt":"2026-01-01T00:00:00.000Z"}],"zones":[{"id":"zone_a","name":"슬램 존"}]}"#.utf8)
    )
    return FestivalCrewFeature.State(
      crewID: "crew_a",
      festival: festival,
      sessionUserID: "user_a",
      live: live(
        state: memberState,
        zoneID: memberState == "leaving" ? nil : "zone_a",
        updatedAt: now.addingTimeInterval(-60)
      )
    )
  }

  private func live(
    state: String,
    zoneID: String?,
    updatedAt: Date
  ) -> FestivalLiveBoardSnapshot.Crew {
    return FestivalLiveBoardSnapshot.Crew(
      id: "crew_a",
      name: "펜타 크루",
      members: [
        .init(
          id: "user_a",
          nickname: "민지",
          state: state,
          zoneID: zoneID,
          updatedAt: updatedAt
        )
      ],
      ownerID: "user_a"
    )
  }

  private func crew(
    state: String,
    ownerID: String = "user_a"
  ) -> FestivalCrew {
    return FestivalCrew(
      id: "crew_a",
      festivalID: "fst_a",
      name: "펜타 크루",
      ownerID: ownerID,
      members: [],
      inviteCode: ownerID == "user_a" ? "K7P2QX" : nil,
      inviteExpiresAt: nil,
      live: FestivalLiveBoardSnapshot.Crew(
        id: "crew_a",
        name: "펜타 크루",
        members: [
          .init(
            id: "user_a",
            nickname: "민지",
            state: state,
            zoneID: "zone_a",
            updatedAt: now
          )
        ],
        ownerID: ownerID
      )
    )
  }
}

/// 테스트마다 필요한 크루 호출만 정한다. 정하지 않은 호출은 테스트 이슈로 남는다.
struct CrewSpy: FestivalCrewUseCaseInterface {
  var detail: FestivalCrew?
  var status: (@Sendable (
    FestivalCrewState,
    String?
  ) throws -> Void)?
  var dissolve: (@Sendable () -> Void)?
  var invite: FestivalCrewInvite?
  var inviteError: FestivalCrewError?
  var join: FestivalCrew?
  var joinError: FestivalCrewError?

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

  func detail(crewID _: String) async throws -> FestivalCrew {
    guard let detail else {
      Issue.record("detail 응답을 정하지 않았다")
      throw FestivalCrewError.unavailable
    }
    return detail
  }

  func updateStatus(
    crewID _: String,
    state: FestivalCrewState,
    zoneID: String?
  ) async throws {
    guard let status else {
      Issue.record("updateStatus 동작을 정하지 않았다")
      throw FestivalCrewError.unavailable
    }
    try status(
      state,
      zoneID
    )
  }

  func dissolve(crewID _: String) async throws {
    guard let dissolve else {
      Issue.record("dissolve 동작을 정하지 않았다")
      throw FestivalCrewError.unavailable
    }
    dissolve()
  }

  func invite(code _: String) async throws -> FestivalCrewInvite {
    if let inviteError { throw inviteError }
    guard let invite else {
      Issue.record("invite 응답을 정하지 않았다")
      throw FestivalCrewError.unavailable
    }
    return invite
  }

  func join(inviteCode _: String) async throws -> FestivalCrew {
    if let joinError { throw joinError }
    guard let join else {
      Issue.record("join 응답을 정하지 않았다")
      throw FestivalCrewError.unavailable
    }
    return join
  }
}
