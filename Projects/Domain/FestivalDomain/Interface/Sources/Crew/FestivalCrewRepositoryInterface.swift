import Dependencies

/// 인증된 사용자의 축제 크루 생성 통신을 정의한다.
public protocol FestivalCrewRepositoryInterface: Sendable {
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

/// 저장소가 주입되지 않은 크루 생성 호출을 테스트 오류로 알린다.
private struct UnregisteredFestivalCrewRepository: FestivalCrewRepositoryInterface {
  func gather(
    crewID: String,
    zoneID: String
  ) async throws {
    reportIssue("festivalCrewRepository.gather 미등록")
    throw FestivalCrewError.unavailable
  }

  func create(
    festivalID _: String,
    name _: String,
    nickname _: String?
  ) async throws -> FestivalCrew {
    reportIssue("festivalCrewRepository.create 미등록")
    throw FestivalCrewError.unavailable
  }
}
