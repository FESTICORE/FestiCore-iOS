import Dependencies

public protocol FestivalCrewRepositoryInterface: Sendable {
  func create(festivalID: String, name: String, nickname: String?) async throws -> FestivalCrew
}

public enum FestivalCrewRepositoryDependency: TestDependencyKey {
  public static var testValue: any FestivalCrewRepositoryInterface { return UnregisteredFestivalCrewRepository() }
  public static var previewValue: any FestivalCrewRepositoryInterface { return testValue }
}

public extension DependencyValues {
  var festivalCrewRepository: any FestivalCrewRepositoryInterface {
    get { return self[FestivalCrewRepositoryDependency.self] }
    set { self[FestivalCrewRepositoryDependency.self] = newValue }
  }
}

private struct UnregisteredFestivalCrewRepository: FestivalCrewRepositoryInterface {
  func create(festivalID _: String, name _: String, nickname _: String?) async throws -> FestivalCrew {
    reportIssue("festivalCrewRepository.create 미등록")
    throw FestivalCrewError.unavailable
  }
}
