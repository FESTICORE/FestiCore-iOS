import Dependencies

/// 크루 생성·상세·상태·초대·크루장 관리 입력을 검증하고 결과를 반환하는 계약이다.
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

  /// 크루 상세와 크루원 존·상태를 받는다. 크루원만 볼 수 있다.
  func detail(crewID: String) async throws -> FestivalCrew

  /// 내 상태를 크루원에게 공유한다. `leaving`이면 서버가 존을 비운다.
  func updateStatus(
    crewID: String,
    state: FestivalCrewState,
    zoneID: String?
  ) async throws

  /// 초대 코드를 새로 만든다. 크루장만 부를 수 있고 이전 코드는 바로 무효가 된다.
  func rotateInvite(crewID: String) async throws -> FestivalCrewInviteCode

  /// 크루 이름을 바꾼다. 크루장만 부를 수 있다.
  func rename(
    crewID: String,
    name: String
  ) async throws -> FestivalCrew

  /// 크루원을 내보낸다. 크루장만 부를 수 있다.
  func removeMember(
    crewID: String,
    userID: String
  ) async throws

  /// 크루장을 다른 크루원에게 넘긴다.
  func transfer(
    crewID: String,
    toUserID: String
  ) async throws -> FestivalCrew

  /// 크루를 해산한다. 크루장만 부를 수 있다.
  func dissolve(crewID: String) async throws

  /// 초대 코드의 크루를 로그인 없이 미리 본다.
  func invite(code: String) async throws -> FestivalCrewInvite

  /// 초대 코드로 크루에 들어간다.
  func join(inviteCode: String) async throws -> FestivalCrew
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
