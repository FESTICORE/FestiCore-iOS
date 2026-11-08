import Dependencies

/// 유스케이스가 주입되지 않은 크루 호출을 테스트 오류로 알린다.
public struct MockFestivalCrewUseCase: FestivalCrewUseCaseInterface {
  public func gather(
    crewID: String,
    zoneID: String
  ) async throws {
    reportIssue("festivalCrewUseCase.gather 미등록")
    throw FestivalCrewError.unavailable
  }

  public init() {}

  public func create(
    festivalID _: String,
    name _: String,
    nickname _: String?
  ) async throws -> FestivalCrew {
    reportIssue("festivalCrewUseCase.create 미등록")
    throw FestivalCrewError.unavailable
  }

  public func detail(crewID _: String) async throws -> FestivalCrew {
    reportIssue("festivalCrewUseCase.detail 미등록")
    throw FestivalCrewError.unavailable
  }

  public func updateStatus(
    crewID _: String,
    state _: FestivalCrewState,
    zoneID _: String?
  ) async throws {
    reportIssue("festivalCrewUseCase.updateStatus 미등록")
    throw FestivalCrewError.unavailable
  }

  public func rotateInvite(crewID _: String) async throws -> FestivalCrewInviteCode {
    reportIssue("festivalCrewUseCase.rotateInvite 미등록")
    throw FestivalCrewError.unavailable
  }

  public func rename(
    crewID _: String,
    name _: String
  ) async throws -> FestivalCrew {
    reportIssue("festivalCrewUseCase.rename 미등록")
    throw FestivalCrewError.unavailable
  }

  public func removeMember(
    crewID _: String,
    userID _: String
  ) async throws {
    reportIssue("festivalCrewUseCase.removeMember 미등록")
    throw FestivalCrewError.unavailable
  }

  public func transfer(
    crewID _: String,
    toUserID _: String
  ) async throws -> FestivalCrew {
    reportIssue("festivalCrewUseCase.transfer 미등록")
    throw FestivalCrewError.unavailable
  }

  public func dissolve(crewID _: String) async throws {
    reportIssue("festivalCrewUseCase.dissolve 미등록")
    throw FestivalCrewError.unavailable
  }

  public func invite(code _: String) async throws -> FestivalCrewInvite {
    reportIssue("festivalCrewUseCase.invite 미등록")
    throw FestivalCrewError.unavailable
  }

  public func join(inviteCode _: String) async throws -> FestivalCrew {
    reportIssue("festivalCrewUseCase.join 미등록")
    throw FestivalCrewError.unavailable
  }
}
