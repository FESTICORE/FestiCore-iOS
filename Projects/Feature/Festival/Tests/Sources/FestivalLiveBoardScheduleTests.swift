import Foundation
import Testing
@testable import Festival

struct FestivalLiveBoardScheduleTests {
  @Test func showsCurrentAndNextForEachStage() throws {
    let pack = try document(#"{"id":"festival","stages":[{"id":"main","name":"메인 무대"},{"id":"sub","name":"서브 무대"}],"sets":[{"id":"later","stageId":"main","artist":"두 번째","startsAt":"2026-10-30T13:00:00+09:00","endsAt":"2026-10-30T14:00:00+09:00"},{"id":"now","stageId":"main","artist":"첫 번째","startsAt":"2026-10-30T12:00:00+09:00","endsAt":"2026-10-30T13:00:00+09:00"},{"id":"sub-next","stageId":"sub","artist":"다른 공연","startsAt":"2026-10-30T12:31:00+09:00"}]}"#)
    let stages = FestivalLiveBoardSchedule.resolve(pack: pack, now: utc("2026-10-30T03:30:00Z"))

    #expect(stages.map(\.name) == ["메인 무대", "서브 무대"])
    #expect(stages[0].current?.artist == "첫 번째")
    #expect(stages[0].previous?.artist == "첫 번째")
    #expect(stages[0].next?.artist == "두 번째")
    #expect(stages[0].current?.progress(
      toward: stages[0].next!.startsAt,
      at: utc("2026-10-30T03:30:00Z")
    ) == 0.5)
    #expect(stages[1].current == nil)
    #expect(stages[1].next?.artist == "다른 공연")
  }

  @Test func exactStartAndEndBoundariesAndFinishedSchedule() throws {
    let pack = try document(#"{"id":"festival","timetable":[{"id":"one","stageName":"메인","artist":"첫 번째","startsAt":"2026-10-30T12:00:00+09:00","endsAt":"2026-10-30T13:00:00+09:00"},{"id":"two","stageName":"메인","artist":"두 번째","startsAt":"2026-10-30T13:00:00+09:00","endsAt":"2026-10-30T14:00:00+09:00"}]}"#)

    let upcoming = FestivalLiveBoardSchedule.resolve(pack: pack, now: utc("2026-10-30T02:59:59Z"))
    #expect(upcoming[0].current == nil)
    #expect(upcoming[0].next?.id == "one")

    let active = FestivalLiveBoardSchedule.resolve(pack: pack, now: utc("2026-10-30T03:00:00Z"))
    #expect(active[0].current?.id == "one")
    #expect(active[0].next?.id == "two")

    let handoff = FestivalLiveBoardSchedule.resolve(pack: pack, now: utc("2026-10-30T04:00:00Z"))
    #expect(handoff[0].current?.id == "two")
    #expect(handoff[0].next == nil)
    #expect(FestivalLiveBoardSchedule.resolve(pack: pack, now: utc("2026-10-30T05:00:00Z")).isEmpty)
  }

  @Test func progressContinuesBetweenSets() throws {
    let pack = try document(#"{"id":"festival","timetable":[{"id":"one","stageName":"메인","artist":"첫 번째","startsAt":"2026-10-30T12:00:00+09:00","endsAt":"2026-10-30T12:40:00+09:00"},{"id":"two","stageName":"메인","artist":"두 번째","startsAt":"2026-10-30T13:00:00+09:00","endsAt":"2026-10-30T14:00:00+09:00"}]}"#)
    let now = utc("2026-10-30T03:45:00Z")
    let stages = FestivalLiveBoardSchedule.resolve(pack: pack, now: now)

    #expect(stages[0].current == nil)
    #expect(stages[0].previous?.id == "one")
    #expect(stages[0].next?.id == "two")
    #expect(stages[0].previous?.progress(toward: stages[0].next!.startsAt, at: now) == 0.75)
  }

  @Test func missingAndInvalidTimesDoNotInventAnActivePerformance() throws {
    let pack = try document(#"{"id":"festival","timetable":[{"id":"missing","stageName":"메인","artist":"시각 없음"},{"id":"invalid","stageName":"메인","artist":"잘못된 시각","startsAt":"tomorrow"},{"id":"naive","stageName":"메인","artist":"시간대 없음","startsAt":"2026-10-30T12:00:00"},{"id":"no-end","stageName":"메인","artist":"종료 미상","startsAt":"2026-10-30T12:00:00+09:00"},{"id":"later","stageName":"메인","artist":"다음","startsAt":"2026-10-30T13:00:00+09:00","endsAt":"2026-10-30T14:00:00+09:00"}]}"#)

    let stages = FestivalLiveBoardSchedule.resolve(pack: pack, now: utc("2026-10-30T03:30:00Z"))
    #expect(stages.count == 1)
    #expect(stages[0].current == nil)
    #expect(stages[0].next?.id == "later")
  }

  @Test func progressTowardNextSetIsClampedToItsTimeWindow() {
    let start = utc("2026-10-30T03:00:00Z")
    let end = utc("2026-10-30T04:00:00Z")
    let slot = FestivalLiveBoardSchedule.Slot(id: "set", artist: "아티스트", startsAt: start, endsAt: end)

    #expect(slot.progress(toward: end, at: utc("2026-10-30T02:30:00Z")) == 0)
    #expect(slot.progress(toward: end, at: utc("2026-10-30T03:30:00Z")) == 0.5)
    #expect(slot.progress(toward: end, at: utc("2026-10-30T04:30:00Z")) == 1)
    #expect(FestivalLiveBoardSchedule.Slot(
      id: "unknown", artist: "아티스트", startsAt: start, endsAt: nil
    ).progress(toward: start, at: end) == 0)
  }

  private func document(_ json: String) throws -> FestivalPackDocument {
    try JSONDecoder().decode(FestivalPackDocument.self, from: Data(json.utf8))
  }

  private func utc(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}
