import Foundation
import Testing
import FestivalDomainInterface

struct FestivalPackDocumentTests {
  @Test("팩의 깃발 설정·구역·출처·일자 시각을 읽는다")
  func decodesLiveBoardFields() throws {
    let pack = try document(#"""
      {"id":"fst_test","flagsEnabled":false,
      "zones":[{"id":"zone_a","name":"메인 앞"},{"id":"zone_b","name":"푸드존"}],
      "source":{"name":"운영팀","url":"https://example.com/source","verifiedAt":"2026-10-20T09:00:00Z"},
      "days":[{"date":"2026-10-20","startsAt":"2026-10-20T13:00:00+09:00",
      "endsAt":"2026-10-20T23:00:00+09:00"}]}
      """#)

    #expect(pack.flagsEnabled == false)
    #expect(pack.zones?.map(\.id) == ["zone_a", "zone_b"])
    #expect(pack.zoneName(for: "zone_a") == "메인 앞")
    #expect(pack.zoneName(for: "missing") == nil)
    #expect(pack.zoneName(for: nil) == nil)
    #expect(pack.source?.name == "운영팀")
    #expect(pack.source?.url == "https://example.com/source")
    #expect(pack.source?.verifiedAt == "2026-10-20T09:00:00Z")
    #expect(pack.days?.first?.startsAt == "2026-10-20T13:00:00+09:00")
    #expect(pack.days?.first?.endsAt == "2026-10-20T23:00:00+09:00")
  }

  @Test("구버전 팩은 새 필드 없이도 읽는다")
  func decodesLegacyPack() throws {
    let pack = try document(#"{"id":"fst_test","days":[{"date":"2026-10-20"}]}"#)

    #expect(pack.eventPeriod == nil)
    #expect(pack.flagsEnabled == nil)
    #expect(pack.zones == nil)
    #expect(pack.source == nil)
    #expect(pack.days?.first?.startsAt == nil)
    #expect(pack.days?.first?.endsAt == nil)
    #expect(pack.zoneName(for: "zone_a") == nil)
  }

  @Test("잘못된 출처 필드와 구역 원소만 버린다")
  func skipsMalformedDisplayMetadata() throws {
    let pack = try document(#"{"id":"fst_test","source":{"name":"운영팀","url":12,"verifiedAt":false},"zones":[{"id":"missing_name"},{"id":"wrong_name","name":12},{"id":"valid","name":"메인 앞"}]}"#)

    #expect(pack.source?.name == "운영팀")
    #expect(pack.source?.url == nil)
    #expect(pack.source?.verifiedAt == nil)
    #expect(pack.zones?.map(\.id) == ["valid"])
    #expect(pack.zoneName(for: "valid") == "메인 앞")
    #expect(pack.zoneName(for: "missing_name") == nil)
  }

  @Test("공연 일정 없는 팩의 개최 기간과 아티스트를 읽는다")
  func decodesMetadataOnlyPack() throws {
    let pack = try document(#"{"id":"fst_test","eventPeriod":{"firstDate":"2026-10-29","lastDate":"2026-10-31"},"days":[],"stages":[],"sets":[],"artists":[{"name":"Artist"}]}"#)

    #expect(pack.eventPeriod?.firstDate == "2026-10-29")
    #expect(pack.eventPeriod?.lastDate == "2026-10-31")
    #expect(pack.artists?.first?.name == "Artist")
    #expect(pack.days?.isEmpty == true)
    #expect(pack.performances.isEmpty)
  }

  @Test("잘못된 개최 기간 메타데이터가 팩 읽기를 막지 않는다")
  func skipsMalformedEventPeriod() throws {
    for period in ["null", "[]", "12", #"{"firstDate":false,"lastDate":"2026-10-31"}"#, #"{"firstDate":"2026-10-29"}"#] {
      let pack = try document("{\"id\":\"fst_test\",\"eventPeriod\":\(period)}")
      #expect(pack.eventPeriod == nil)
    }
  }

  private func document(_ json: String) throws -> FestivalPackDocument {
    try JSONDecoder().decode(FestivalPackDocument.self, from: Data(json.utf8))
  }
}
