import FestivalDomainInterface
import Dependencies

/// 테스트 저장소 대역이 직접 구현하지 않은 크루 호출은 테스트 이슈로 기록하고 실패시킨다.
extension FestivalCrewRepositoryInterface {
  func detail(crewID _: String) async throws -> FestivalCrew {
    reportIssue("테스트 대역에 detail이 없습니다")
    throw FestivalCrewError.unavailable
  }

  func updateStatus(
    crewID _: String,
    state _: FestivalCrewState,
    zoneID _: String?
  ) async throws {
    reportIssue("테스트 대역에 updateStatus가 없습니다")
    throw FestivalCrewError.unavailable
  }

  func rotateInvite(crewID _: String) async throws -> FestivalCrewInviteCode {
    reportIssue("테스트 대역에 rotateInvite가 없습니다")
    throw FestivalCrewError.unavailable
  }

  func rename(
    crewID _: String,
    name _: String
  ) async throws -> FestivalCrew {
    reportIssue("테스트 대역에 rename이 없습니다")
    throw FestivalCrewError.unavailable
  }

  func removeMember(
    crewID _: String,
    userID _: String
  ) async throws {
    reportIssue("테스트 대역에 removeMember가 없습니다")
    throw FestivalCrewError.unavailable
  }

  func transfer(
    crewID _: String,
    toUserID _: String
  ) async throws -> FestivalCrew {
    reportIssue("테스트 대역에 transfer가 없습니다")
    throw FestivalCrewError.unavailable
  }

  func dissolve(crewID _: String) async throws {
    reportIssue("테스트 대역에 dissolve가 없습니다")
    throw FestivalCrewError.unavailable
  }

  func invite(code _: String) async throws -> FestivalCrewInvite {
    reportIssue("테스트 대역에 invite가 없습니다")
    throw FestivalCrewError.unavailable
  }

  func join(inviteCode _: String) async throws -> FestivalCrew {
    reportIssue("테스트 대역에 join이 없습니다")
    throw FestivalCrewError.unavailable
  }
}
