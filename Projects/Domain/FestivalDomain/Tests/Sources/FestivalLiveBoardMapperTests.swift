import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalLiveBoardMapperTests {
  /// Figma S01 B 도착 예정 순: 깃발 목록의 공개 관람 계획을 활성 깃발에 붙이고, 없거나 형식이 틀리면 빈 배열로 둔다.
  @Test func activeFlagsCarryPublicPlanFromFlagProfiles() throws {
    let board = try JSONDecoder().decode(
      FestivalLiveBoardDataDTO.self,
      from: Data(#"""
      {"festivalId":"fst","serverAt":"2026-10-20T06:00:00Z","activeFlags":[
        {"flagId":"flg_a","status":"active","zoneId":null,"activity":null,"updatedAt":"2026-10-20T05:00:00Z"},
        {"flagId":"flg_b","status":"active","zoneId":null,"activity":null,"updatedAt":"2026-10-20T05:00:00Z"},
        {"flagId":"flg_c","status":"active","zoneId":null,"activity":null,"updatedAt":"2026-10-20T05:00:00Z"}
      ]}
      """#.utf8)
    )
    let profiles = try JSONDecoder().decode(
      FestivalFlagsDataDTO.self,
      from: Data(#"""
      {"items":[
        {"id":"flg_a","name":"A","plan":["set_1","set_2"]},
        {"id":"flg_b","name":"B"},
        {"id":"flg_c","name":"C","plan":"wrong"}
      ]}
      """#.utf8)
    )

    let snapshot = try board.toDomain(
      profiles: profiles,
      imageURL: { _ in return nil }
    )

    #expect(snapshot.activeFlags.map(\.plannedSetIDs) == [["set_1", "set_2"], [], []])
  }
}
