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
    let remote = try JSONDecoder().decode(FestiCoreFestivalActivityAttributes.ContentState.self, from: payload)
    let start = Date(timeIntervalSinceReferenceDate: 60)
    let end = Date(timeIntervalSinceReferenceDate: 90_000)

    for phase in [FestiCoreFestivalActivityAttributes.ContentState.Phase.ongoing, .finished] {
      let content = FestiCoreFestivalLiveActivity.content(
        phase: phase, startDate: start, endDate: end, preserving: remote
      )
      var expected = remote
      expected.phase = phase
      expected.startDate = start
      expected.endDate = end
      #expect(content.state == expected)
      #expect(content.staleDate == (phase == .ongoing ? end : nil))
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
}
