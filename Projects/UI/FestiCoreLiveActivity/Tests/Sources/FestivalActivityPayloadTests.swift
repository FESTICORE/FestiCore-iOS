import ActivityKit
import FestivalDomainInterface
import Foundation
import Testing
@testable import FestiCoreLiveActivity

struct FestivalActivityPayloadTests {
  @Test func localPackProducesCurrentStageAndNextSavedPerformance() throws {
    let pack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"""
      {
        "id":"festival",
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
    #expect(content.nowStages.first?.artist == "지금 공연")
    #expect(content.nextMine?.setId == "next")
    #expect(content.nextMine?.stageId == "C")
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
    #expect(state.pinnedFlag?.status == .active)
    #expect(state.crewSummary?.memberCount == 4)
    #expect(state.leaveAt == nil)
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
}
