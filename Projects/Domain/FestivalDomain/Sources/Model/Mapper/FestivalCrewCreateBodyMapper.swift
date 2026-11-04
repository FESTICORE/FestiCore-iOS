import APIEndpoint

enum FestivalCrewCreateBodyMapper {
  static func body(
    festivalID: String,
    name: String,
    nickname: String?
  ) -> CrewCreateBody {
    return CrewCreateBody(
      festivalId: festivalID,
      name: name,
      nickname: nickname
    )
  }
}
