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

  /// Figma S07 F: 보낸 사람은 응답 버튼 대신 응답 요약을 본다.
  @Test func presentationShowsSenderGatherSummaryAndInactiveMember() {
    var initial = state(memberState: "leaving")
    initial.live = FestivalLiveBoardSnapshot.Crew(
      id: "crew_a",
      name: "펜타 크루",
      members: initial.live?.members ?? [],
      ownerID: "user_a",
      gatherRequest: .init(
        id: "gth_1",
        zoneID: "zone_a",
        byUserID: "user_a",
        at: now.addingTimeInterval(-120),
        summary: .init(
          going: 2,
          ack: 1
        )
      )
    )
    let presentation = FestivalCrewPresentation(
      crew: initial,
      now: now
    )
    #expect(presentation.gather == .init(
      title: "민지: 슬램 존으로 모여!",
      detail: "2분 전 · 크루원 모두에게 소리 알림을 보냈어요",
      actions: nil,
      summary: "가는 중 2명 · 확인 1명"
    ))
    #expect(presentation.members.first?.isInactive == true)
    #expect(presentation.summary == "1명 · 1/1(목) 자정까지 유지")
  }

  /// Figma S07 F: 받은 크루원은 '가는 중'·'확인' 버튼을 보고, 10분이 지나면 배너가 내려간다.
  @Test func presentationShowsReceiverActionsUntilExpiry() {
    let initial = gatherState(byUserID: "user_b")
    let presentation = FestivalCrewPresentation(
      crew: initial,
      now: now
    )
    #expect(presentation.gather == .init(
      title: "준호: 슬램 존으로 모여!",
      detail: "방금 · 크루원 모두에게 소리 알림을 보냈어요",
      actions: .init(
        goingTitle: "슬램 존으로 가는 중",
        selected: nil,
        isResponding: false
      ),
      summary: nil
    ))
    let expired = FestivalCrewPresentation(
      crew: initial,
      now: now.addingTimeInterval(10 * 60)
    )
    #expect(expired.gather == nil)
  }

  @Test func respondToGatherIgnoresDuplicateTapAndKeepsReply() async {
    let calls = LockIsolated(0)
    let reply = FestivalCrewGatherReply(
      gatherID: "gth_1",
      userID: "user_a",
      nickname: "민지",
      response: .going,
      respondedAt: now
    )
    let store = TestStore(initialState: gatherState(byUserID: "user_b")) {
      FestivalCrewFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewSpy(respond: { gatherID, response in
        calls.withValue { $0 += 1 }
        #expect(gatherID == "gth_1")
        #expect(response == .going)
        return reply
      })
    }
    await store.send(.view(.gatherResponseTapped(.going))) { $0.isRespondingGather = true }
    await store.receive(\.async.respondToGather)
    await store.receive(\.inner.gatherResponded) {
      $0.isRespondingGather = false
      $0.gatherReply = reply
    }
    // 이미 고른 응답을 다시 눌러도 보내지 않는다.
    await store.send(.view(.gatherResponseTapped(.going)))
    #expect(calls.value == 1)
  }

  /// 응답을 기다리는 동안 다시 눌러도 보내지 않는다. 기본 Mock은 호출되면 테스트 이슈를 남긴다.
  @Test func respondingGatherIgnoresAnotherTap() async {
    var initial = gatherState(byUserID: "user_b")
    initial.isRespondingGather = true
    let store = TestStore(initialState: initial) {
      FestivalCrewFeature()
    }
    await store.send(.view(.gatherResponseTapped(.ack)))
  }

  @Test func senderCannotRespondToOwnGather() async {
    let store = TestStore(initialState: gatherState(byUserID: "user_a")) {
      FestivalCrewFeature()
    }
    await store.send(.view(.gatherResponseTapped(.going)))
  }

  @Test func expiredGatherDismissesBannerAndShowsToast() async {
    let clock = TestClock()
    let serverCrew = crew(state: "here")
    let initial = gatherState(byUserID: "user_b")
    let store = TestStore(initialState: initial) {
      FestivalCrewFeature()
    } withDependencies: {
      $0.continuousClock = clock
      $0.festivalCrewUseCase = CrewSpy(
        detail: serverCrew,
        respond: { _, _ in throw FestivalCrewError.gatherExpired }
      )
    }
    await store.send(.view(.gatherResponseTapped(.ack))) { $0.isRespondingGather = true }
    await store.receive(\.async.respondToGather)
    await store.receive(\.inner.gatherResponseFailed) {
      $0.isRespondingGather = false
      $0.expiredGatherID = "gth_1"
      $0.toast = .gatherExpired
    }
    #expect(FestivalCrewPresentation(
      crew: store.state,
      now: now
    ).gather == nil)
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.crew = serverCrew
      $0.live = serverCrew.live
      $0.load = .loaded
    }
    await clock.advance(by: FestivalCrewFeature.toastDuration)
    await store.receive(\.inner.toastExpired) { $0.toast = nil }
  }

  /// Figma S07 I: 끝난 크루 안내 띠에 페스티벌 이름을 넣는다.
  @Test func festivalNameJosaFollowsLastSound() {
    #expect("원더리벳 2026".withIGa == "원더리벳 2026이")
    #expect("펜타포트".withIGa == "펜타포트가")
    #expect("락 페스티벌".withIGa == "락 페스티벌이")
    #expect("Fest 2025".withIGa == "Fest 2025가")
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

  /// Figma S07: 크루는 마지막 공연이 끝난 날의 자정(KST)까지 유지한다(서버 crewArchiveTime과 같은 기준).
  @Test(arguments: [
    ("2026-11-21T22:00:00+09:00", "2026-11-22T23:00:00+09:00", "2026-11-23T00:00:00+09:00"),
    ("2026-11-23T01:00:00+09:00", "2026-11-23T01:00:00+09:00", "2026-11-24T00:00:00+09:00"),
    ("2026-11-23T00:00:00+09:00", "2026-11-23T00:00:00+09:00", "2026-11-23T00:00:00+09:00"),
  ])
  func archiveTimeIsMidnightAfterLastShow(
    firstEnd: String,
    lastEnd: String,
    expected: String
  ) throws {
    let json = #"{"id":"fst_a","days":[{"endsAt":"\#(firstEnd)"},{"endsAt":"\#(lastEnd)"}]}"#
    let festival = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(json.utf8)
    )
    #expect(FestivalCrewFeature.State.archiveTime(festival) == expected.isoDate)
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

  /// 민지(나)와 준호가 있는 크루에 `byUserID`가 보낸 진행 중 모여
  private func gatherState(byUserID: String) -> FestivalCrewFeature.State {
    var initial = state(memberState: "here")
    initial.live = FestivalLiveBoardSnapshot.Crew(
      id: "crew_a",
      name: "펜타 크루",
      members: [
        .init(
          id: "user_a",
          nickname: "민지",
          state: "here",
          zoneID: "zone_a",
          updatedAt: now
        ),
        .init(
          id: "user_b",
          nickname: "준호",
          state: "here",
          zoneID: "zone_a",
          updatedAt: now
        ),
      ],
      ownerID: "user_a",
      gatherRequest: .init(
        id: "gth_1",
        zoneID: "zone_a",
        byUserID: byUserID,
        at: now,
        expiresAt: now.addingTimeInterval(10 * 60)
      )
    )
    return initial
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
  var respond: (@Sendable (
    String,
    FestivalCrewGatherResponse
  ) throws -> FestivalCrewGatherReply)?
  var leave: (@Sendable (String) throws -> Void)?

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

  func respondToGather(
    crewID _: String,
    gatherID: String,
    response: FestivalCrewGatherResponse
  ) async throws -> FestivalCrewGatherReply {
    guard let respond else {
      Issue.record("respondToGather 동작을 정하지 않았다")
      throw FestivalCrewError.unavailable
    }
    return try respond(
      gatherID,
      response
    )
  }

  func leave(crewID: String) async throws {
    guard let leave else {
      Issue.record("leave 동작을 정하지 않았다")
      throw FestivalCrewError.unavailable
    }
    try leave(crewID)
  }
}
