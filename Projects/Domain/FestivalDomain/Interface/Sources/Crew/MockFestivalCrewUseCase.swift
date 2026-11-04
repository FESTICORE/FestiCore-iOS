import Dependencies

/// 유스케이스가 주입되지 않은 크루 생성 호출을 테스트 오류로 알린다.
public struct MockFestivalCrewUseCase: FestivalCrewUseCaseInterface {
  public init() {}

  public func create(
    festivalID _: String,
    name _: String,
    nickname _: String?
  ) async throws -> FestivalCrew {
    reportIssue("festivalCrewUseCase.create 미등록")
    throw FestivalCrewError.unavailable
  }
}
