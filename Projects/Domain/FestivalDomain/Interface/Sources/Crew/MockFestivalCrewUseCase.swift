import Dependencies

public struct MockFestivalCrewUseCase: FestivalCrewUseCaseInterface {
  public init() {}

  public func create(festivalID _: String, name _: String, nickname _: String?) async throws -> FestivalCrew {
    reportIssue("festivalCrewUseCase.create 미등록")
    throw FestivalCrewError.unavailable
  }
}
