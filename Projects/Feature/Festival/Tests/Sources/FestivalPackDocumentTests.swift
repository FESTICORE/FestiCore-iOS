import Foundation
import Testing
@testable import Festival

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

  private func document(_ json: String) throws -> FestivalPackDocument {
    try JSONDecoder().decode(FestivalPackDocument.self, from: Data(json.utf8))
  }
}
