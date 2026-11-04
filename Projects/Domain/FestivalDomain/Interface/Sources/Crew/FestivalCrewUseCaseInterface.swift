import Dependencies

/// 크루 생성 입력을 검증하고 생성 결과를 반환하는 계약이다.
public protocol FestivalCrewUseCaseInterface: Sendable {
  /// 선택한 공식 존으로 크루 집결 요청을 보낸다.
  func gather(
    crewID: String,
    zoneID: String
  ) async throws

  func create(
    festivalID: String,
    name: String,
    nickname: String?
  ) async throws -> FestivalCrew
}

public enum FestivalCrewUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalCrewUseCaseInterface { return MockFestivalCrewUseCase() }
  public static var previewValue: any FestivalCrewUseCaseInterface { return testValue }
}

public extension DependencyValues {
  var festivalCrewUseCase: any FestivalCrewUseCaseInterface {
    get { return self[FestivalCrewUseCaseDependency.self] }
    set { self[FestivalCrewUseCaseDependency.self] = newValue }
  }
}
