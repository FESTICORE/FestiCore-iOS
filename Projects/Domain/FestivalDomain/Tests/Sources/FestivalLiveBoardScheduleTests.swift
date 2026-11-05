import FestivalDomainInterface
import Foundation
import Testing

struct FestivalLiveBoardScheduleTests {
  @Test func entriesRejectInvalidValuesAndSortEqualStartsByID() throws {
    let pack = try document(
      #"{"id":"festival","stages":[{"id":"main","name":"메인"},{"id":"main","name":"중복"}],"sets":[{"id":"b","stageId":"main","artist":" B ","startsAt":"2026-10-30T03:00:00Z"},{"id":"a","stageId":"main","artist":"A","startsAt":"2026-10-30T03:00:00Z"},{"id":"bad","stageId":"main","artist":"X","startsAt":"2026-10-30T03:00:00Z","endsAt":"2026-10-30T02:00:00Z"},{"id":"naive","stageId":"main","artist":"X","startsAt":"2026-10-30T03:00:00"},{"id":"blank","stageId":"main","artist":" ","startsAt":"2026-10-30T03:00:00Z"}]}"#
    )
    let entries = FestivalLiveBoardSchedule.entries(from: pack)

    #expect(entries.map(\.slot.id) == ["a", "b"])
    #expect(entries.map(\.stageName) == ["메인", "메인"])
    #expect(entries.last?.slot.artist == "B")
  }

  @Test func stageSchedulePreservesStageOrderAndExclusiveEnd() throws {
    let pack = try document(
      #"{"id":"festival","sets":[{"id":"sub","stageName":"서브","artist":"S","startsAt":"2026-10-30T04:00:00Z"},{"id":"one","stageName":"메인","artist":"A","startsAt":"2026-10-30T03:00:00Z","endsAt":"2026-10-30T04:00:00Z"},{"id":"two","stageName":"메인","artist":"B","startsAt":"2026-10-30T04:00:00Z","endsAt":"2026-10-30T05:00:00Z"}]}"#
    )
    let stages = FestivalLiveBoardSchedule.stages(
      from: pack,
      at: date("2026-10-30T03:00:00Z")
    )
    #expect(stages.map(\.name) == ["서브", "메인"])
    #expect(stages[1].current?.id == "one")
    #expect(stages[1].next?.id == "two")
    let handoff = FestivalLiveBoardSchedule.stages(
      from: pack,
      at: date("2026-10-30T04:00:00Z")
    )
    #expect(handoff.map(\.name) == ["메인"])
    #expect(handoff.first?.current?.id == "two")
    #expect(
      FestivalLiveBoardSchedule.stages(
        from: pack,
        at: date("2026-10-30T05:00:00Z")
      ).isEmpty)
  }

  @Test func unknownEndNeverBecomesCurrentButRemainsPrevious() throws {
    let pack = try document(
      #"{"id":"festival","sets":[{"id":"one","stageName":"메인","artist":"A","startsAt":"2026-10-30T03:00:00Z"},{"id":"two","stageName":"메인","artist":"B","startsAt":"2026-10-30T04:00:00Z"}]}"#
    )
    let stages = FestivalLiveBoardSchedule.stages(
      from: pack,
      at: date("2026-10-30T03:30:00Z")
    )
    #expect(stages.first?.current == nil)
    #expect(stages.first?.previous?.id == "one")
    #expect(stages.first?.next?.id == "two")
  }

  private func document(_ json: String) throws -> FestivalPackDocument {
    return try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(json.utf8)
    )
  }

  private func date(_ value: String) -> Date {
    return ISO8601DateFormatter().date(from: value)!
  }
}
