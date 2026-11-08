import ActivityKit
import Dependencies
import FestivalDomainInterface
import Foundation
import Testing
@testable import FestiCoreLiveActivity

struct FestivalActivityPayloadTests {
  @Test func resolvesLiveActivityClientWithoutAppRegistration() {
    withDependencies {
      $0.context = .live
    } operation: {
      @Dependency(\.festivalLiveActivityClient) var client
      _ = client
    }
  }

  @Test func localPackProducesCurrentStageAndNextSavedPerformance() throws {
    let pack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"""
      {
        "id":"festival",
        "stages":[
          {"id":"A","name":"첫째 무대"},
          {"id":"C","name":"셋째 무대"}
        ],
        "sets":[
          {"id":"now","artist":"지금 공연","stageId":"A","startsAt":"2026-11-07T08:30:00Z","endsAt":"2026-11-07T09:30:00Z"},
          {"id":"later","artist":"다음 공연","stageId":"B","startsAt":"2026-11-07T11:00:00Z","endsAt":"2026-11-07T12:00:00Z"},
          {"id":"next","artist":"내 공연","stageId":"C","startsAt":"2026-11-07T10:00:00Z","endsAt":"2026-11-07T11:00:00Z"}
        ]
      }
      """#.utf8))
    let now = try #require(ISO8601DateFormatter().date(from: "2026-11-07T09:00:00Z"))
    let content = FestivalActivityPresentation.from(
      pack: pack,
      savedSetIDs: ["later", "next"],
      now: now
    )

    #expect(content.nowStages.map(\.setId) == ["now"])
    #expect(content.nowStages.first?.stageId == "A")
    #expect(content.nowStages.first?.stageName == "첫째 무대")
    #expect(content.nowStages.first?.artist == "지금 공연")
    #expect(content.nextMine?.setId == "next")
    #expect(content.nextMine?.stageId == "C")
    #expect(content.nextMine?.stageName == "셋째 무대")
  }

  @Test func activityStartUsesMatchingSharedSnapshotForNextSavedPerformance() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-11-07T09:00:00Z"))
    let snapshot = FestivalWidgetSnapshot(
      festivalID: "festival",
      festivalName: "축제",
      firstDay: nil,
      lastDay: nil,
      updatedAt: now,
      hasPack: true,
      performances: [
        .init(
          id: "past",
          artist: "지난 공연",
          stageName: "지난 무대",
          startsAt: now.addingTimeInterval(-3_600),
          endsAt: now.addingTimeInterval(-1_800),
          isSaved: true
        ),
        .init(
          id: "next",
          artist: "저장한 다음 공연",
          stageName: "메인 무대",
          startsAt: now.addingTimeInterval(3_600),
          endsAt: now.addingTimeInterval(7_200),
          isSaved: true
        ),
        .init(
          id: "unsaved",
          artist: "저장 안 한 공연",
          stageName: "서브 무대",
          startsAt: now.addingTimeInterval(1_800),
          endsAt: now.addingTimeInterval(5_400),
          isSaved: false
        ),
      ]
    )

    let next = FestivalActivityWidgetContent.nextMine(
      snapshot: snapshot,
      festivalID: "festival",
      now: now
    )

    #expect(next?.setId == "next")
    #expect(next?.artist == "저장한 다음 공연")
    #expect(next?.stageName == "메인 무대")
    #expect(next?.startsAt.isoDate == now.addingTimeInterval(3_600))
  }

  @Test func confirmedEmptyScheduleIsNotFilledFromSharedSnapshot() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let snapshot = FestivalWidgetSnapshot(
      festivalID: "festival",
      festivalName: "축제",
      firstDay: nil,
      lastDay: nil,
      updatedAt: now,
      hasPack: true,
      performances: [
        .init(
          id: "stale",
          artist: "저장 취소한 공연",
          stageName: "메인 무대",
          startsAt: now.addingTimeInterval(3_600),
          endsAt: now.addingTimeInterval(7_200),
          isSaved: true
        ),
      ]
    )
    var state = FestiCoreFestivalActivityAttributes.ContentState(
      phase: .ongoing,
      startDate: now
    )

    // 서버 payload처럼 확인 여부가 없으면 공유 저장 일정으로 채운다.
    #expect(FestivalActivityWidgetContent.resolvedNextMine(
      state: state,
      snapshot: snapshot,
      festivalID: "festival",
      now: now
    )?.setId == "stale")

    // 앱이 내 일정이 비었다고 확인했으면 오래된 스냅샷을 쓰지 않는다.
    state.isNextMineConfirmed = true
    #expect(FestivalActivityWidgetContent.resolvedNextMine(
      state: state,
      snapshot: snapshot,
      festivalID: "festival",
      now: now
    ) == nil)
  }

  @Test func activityStartDoesNotReadAnotherFestival() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let snapshot = FestivalWidgetSnapshot(
      festivalID: "other-festival",
      festivalName: "다른 축제",
      firstDay: nil,
      lastDay: nil,
      updatedAt: now,
      hasPack: true,
      performances: [
        .init(
          id: "next",
          artist: "저장한 공연",
          stageName: "메인 무대",
          startsAt: now.addingTimeInterval(3_600),
          endsAt: now.addingTimeInterval(7_200),
          isSaved: true
        ),
      ]
    )

    #expect(FestivalActivityWidgetContent.nextMine(
      snapshot: snapshot,
      festivalID: "festival",
      now: now
    ) == nil)
  }

  @Test func activityStartDoesNotReadSavedPerformancesWithoutPack() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let snapshot = FestivalWidgetSnapshot(
      festivalID: "festival",
      festivalName: "축제",
      firstDay: nil,
      lastDay: nil,
      updatedAt: now,
      hasPack: false,
      performances: [
        .init(
          id: "next",
          artist: "저장한 공연",
          stageName: "메인 무대",
          startsAt: now.addingTimeInterval(3_600),
          endsAt: now.addingTimeInterval(7_200),
          isSaved: true
        ),
      ]
    )

    #expect(FestivalActivityWidgetContent.nextMine(
      snapshot: snapshot,
      festivalID: "festival",
      now: now
    ) == nil)
  }

  @Test func pushToStartStateDecodesOwnSetAndStage() throws {
    let payload = Data(#"""
      {
        "phase": "upcoming",
        "startDate": 0,
        "endDate": 86400,
        "nowStages": [],
        "nextMine": {
          "setId": "set_1",
          "stageId": "stage_1",
          "artist": "테스트 아티스트",
          "startsAt": "2026-11-07T19:00:00+09:00"
        },
        "pinnedFlag": null,
        "crewSummary": null,
        "leaveAt": null
      }
      """#.utf8)

    let state = try JSONDecoder().decode(
      FestiCoreFestivalActivityAttributes.ContentState.self,
      from: payload
    )

    #expect(state.phase == .upcoming)
    #expect(state.startDate == Date(timeIntervalSinceReferenceDate: 0))
    #expect(state.endDate == Date(timeIntervalSinceReferenceDate: 86_400))
    #expect(state.nextMine?.setId == "set_1")
    #expect(state.nextMine?.stageId == "stage_1")
    #expect(state.nextMine?.stageName == nil)
    #expect(state.nextMine?.artist == "테스트 아티스트")
    #expect(state.nextMine?.startsAt == "2026-11-07T19:00:00+09:00")
  }

  @Test func updateStateDecodesCurrentStagesAndOptionalSections() throws {
    let payload = Data(#"""
      {
        "phase": "ongoing",
        "startDate": 0,
        "endDate": 86400,
        "nowStages": [{
          "setId": "set_now",
          "stageId": "stage_a",
          "artist": "지금 공연",
          "startsAt": "2026-11-07T18:00:00+09:00",
          "endsAt": "2026-11-07T19:00:00+09:00"
        }],
        "nextMine": null,
        "pinnedFlag": {
          "flagId": "flag_1",
          "status": "active",
          "zoneId": "zone_1",
          "activity": "이동 중"
        },
        "crewSummary": {
          "crewId": "crew_1",
          "name": "우리 크루",
          "memberCount": 4,
          "hereCount": 2,
          "gatherZoneId": null
        },
        "leaveAt": null
      }
      """#.utf8)

    let state = try JSONDecoder().decode(
      FestiCoreFestivalActivityAttributes.ContentState.self,
      from: payload
    )

    #expect(state.nowStages.first?.artist == "지금 공연")
    #expect(state.nowStages.first?.stageId == "stage_a")
    #expect(state.nowStages.first?.stageName == nil)
    #expect(state.pinnedFlag?.status == .active)
    #expect(state.crewSummary?.memberCount == 4)
    #expect(state.leaveAt == nil)
  }

  @Test func localPhaseUpdatesPreserveRemoteContent() throws {
    let payload = Data(#"""
      {
        "phase": "upcoming", "startDate": 0, "endDate": 86400,
        "nowStages": [{"setId":"now","stageId":"main","artist":"Now","startsAt":"2026-11-20T23:00:00+09:00","endsAt":"2026-11-21T02:00:00+09:00"}],
        "nextMine": {"setId":"next","stageId":"main","artist":"Next","startsAt":"2026-11-21T01:00:00+09:00"},
        "pinnedFlag": {"flagId":"flag","status":"active","zoneId":"zone","activity":"이동 중"},
        "crewSummary": {"crewId":"crew","name":"우리 크루","memberCount":4,"hereCount":2,"gatherZoneId":"zone"},
        "leaveAt": 72000
      }
      """#.utf8)
    let remote = try JSONDecoder().decode(
      FestiCoreFestivalActivityAttributes.ContentState.self,
      from: payload
    )
    let start = Date(timeIntervalSinceReferenceDate: 60)
    let end = Date(timeIntervalSinceReferenceDate: 90_000)

    for phase in [FestiCoreFestivalActivityAttributes.ContentState.Phase.ongoing, .finished] {
      let content = FestiCoreFestivalLiveActivity.content(
        phase: phase,
        startDate: start,
        endDate: end,
        previousState: remote,
        updatedAt: start
      )
      var expected = remote
      expected.phase = phase
      expected.startDate = start
      expected.endDate = end
      #expect(content.state == expected)
      #expect(content.staleDate == (phase == .ongoing ? start.addingTimeInterval(3_600) : nil))

      let cleared = FestiCoreFestivalLiveActivity.content(
        phase: phase,
        startDate: start,
        endDate: end,
        nowStages: [],
        nextMine: nil,
        previousState: remote,
        updatedAt: start
      )
      expected.nowStages = []
      expected.nextMine = nil
      #expect(cleared.state == expected)

      // 내 일정을 아직 모르면 공연 목록만 바꾸고 다음 내 일정은 지우지 않는다.
      let unknownSchedule = FestiCoreFestivalLiveActivity.content(
        phase: phase,
        startDate: start,
        endDate: end,
        nowStages: [],
        nextMine: nil,
        isNextMineKnown: false,
        previousState: remote,
        updatedAt: start
      )
      expected.nextMine = remote.nextMine
      #expect(unknownSchedule.state == expected)

      // 내 일정이 비었다고 확인되면 팩 갱신이 없어도 다음 내 일정을 지운다.
      let emptySchedule = FestiCoreFestivalLiveActivity.content(
        phase: phase,
        startDate: start,
        endDate: end,
        nextMine: nil,
        isNextMineKnown: true,
        previousState: remote,
        updatedAt: start
      )
      expected.nowStages = remote.nowStages
      expected.nextMine = nil
      expected.isNextMineConfirmed = true
      #expect(emptySchedule.state == expected)
    }
  }

  @Test func locallyStartedStateKeepsServerFieldsEmpty() {
    let state = FestiCoreFestivalActivityAttributes.ContentState(
      phase: .upcoming,
      startDate: .now
    )

    #expect(state.nowStages.isEmpty)
    #expect(state.nextMine == nil)
    #expect(state.pinnedFlag == nil)
    #expect(state.crewSummary == nil)
  }

  @Test func localActivityBecomesStaleOneHourAfterLastUpdate() {
    let updatedAt = Date(timeIntervalSince1970: 1_000)

    #expect(FestiCoreFestivalLiveActivity.staleDate(
      for: .upcoming,
      updatedAt: updatedAt
    ) == updatedAt.addingTimeInterval(3_600))
    #expect(FestiCoreFestivalLiveActivity.staleDate(
      for: .ongoing,
      updatedAt: updatedAt
    ) == updatedAt.addingTimeInterval(3_600))
    #expect(FestiCoreFestivalLiveActivity.staleDate(
      for: .finished,
      updatedAt: updatedAt
    ) == nil)
  }
}

struct FestivalActivityCompanionTextTests {
  @Test func pinnedFlagLineUsesServerNameAndActivity() throws {
    let state = try JSONDecoder().decode(
      FestiCoreFestivalActivityAttributes.ContentState.PinnedFlag.self,
      from: Data(#"{"flagId":"flg_1","name":"호락호락","status":"active","zoneId":null,"activity":"slam"}"#.utf8)
    )
    #expect(FestivalActivityWidgetContent.pinnedFlagText(state) == "호락호락 · 슬램")
  }

  @Test func pinnedFlagLineFallsBackForOldPayloadAndResting() throws {
    let state = try JSONDecoder().decode(
      FestiCoreFestivalActivityAttributes.ContentState.PinnedFlag.self,
      from: Data(#"{"flagId":"flg_1","status":"resting","zoneId":null,"activity":"slam"}"#.utf8)
    )
    #expect(FestivalActivityWidgetContent.pinnedFlagText(state) == "내 깃발 · 쉬는 중")
    #expect(FestivalActivityWidgetContent.pinnedFlagText(nil) == nil)
  }

  @Test func crewLineShowsMembersOnSite() throws {
    let crew = try JSONDecoder().decode(
      FestiCoreFestivalActivityAttributes.ContentState.CrewSummary.self,
      from: Data(#"{"crewId":"crew","name":"락인들","memberCount":4,"hereCount":3,"gatherZoneId":null}"#.utf8)
    )
    #expect(FestivalActivityWidgetContent.crewText(crew) == "크루 4명 · 3명 현장")
  }
}
