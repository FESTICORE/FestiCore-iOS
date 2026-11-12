/// 집결 요청에서 서버가 확정한 존과 모여 ID를 확인한다.
struct FestivalCrewGatherDataDTO: Decodable, Sendable {
  /// 응답 API에 쓰는 모여 ID. 이전 서버 응답에는 없다.
  let id: String?
  let zoneId: String
}
