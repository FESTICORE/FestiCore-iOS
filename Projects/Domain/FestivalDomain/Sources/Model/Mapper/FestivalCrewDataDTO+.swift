import FestivalDomainInterface
import Foundation

extension FestivalCrewDataDTO {
  func toDomain() throws -> FestivalCrew {
    guard !id.isEmpty, !festivalId.isEmpty, !name.isEmpty, !ownerId.isEmpty else {
      throw FestivalCrewError.invalidResponse
    }
    let members = try members.map { member -> FestivalCrew.Member in
      guard !member.userId.isEmpty, !member.nickname.isEmpty,
            let joinedAt = Self.parseDate(member.joinedAt) else {
        throw FestivalCrewError.invalidResponse
      }
      return FestivalCrew.Member(
        userID: member.userId,
        nickname: member.nickname,
        joinedAt: joinedAt
      )
    }
    if let live, live.id != id { throw FestivalCrewError.invalidResponse }
    return FestivalCrew(
      id: id,
      festivalID: festivalId,
      name: name,
      ownerID: ownerId,
      members: members,
      inviteCode: inviteCode,
      inviteExpiresAt: try Self.optionalDate(inviteExpiresAt),
      live: live?.toDomain(),
      archivedAt: try Self.optionalDate(archivedAt)
    )
  }

  static func parseDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    return ISO8601DateFormatter().date(from: value)
  }

  /// 값이 있으면 반드시 날짜여야 한다. 형식이 틀리면 응답 전체를 거부한다.
  private static func optionalDate(_ value: String?) throws -> Date? {
    guard let value else { return nil }
    guard let date = parseDate(value) else { throw FestivalCrewError.invalidResponse }
    return date
  }
}

extension FestivalCrewInviteDataDTO {
  func toDomain(code: String) throws -> FestivalCrewInvite {
    guard !crewName.isEmpty, !festivalId.isEmpty, memberCount >= 0,
          let expiresAt = FestivalCrewDataDTO.parseDate(expiresAt) else {
      throw FestivalCrewError.invalidResponse
    }
    return FestivalCrewInvite(
      code: code,
      crewName: crewName,
      festivalID: festivalId,
      festivalName: festivalName,
      inviterNickname: ownerNickname,
      memberCount: memberCount,
      expiresAt: expiresAt,
      // 이름이 빈 줄은 그리지 않고, 주소가 틀리면 기본 아바타로 둔다.
      memberPreview: (memberPreview ?? []).compactMap { member in
        guard !member.nickname.isEmpty else { return nil }
        return FestivalCrewInvite.Member(
          nickname: member.nickname,
          avatarURL: member.avatarUrl.flatMap(URL.init(string:))
        )
      }
    )
  }
}

extension FestivalCrewInviteCodeDataDTO {
  func toDomain() throws -> FestivalCrewInviteCode {
    guard !inviteCode.isEmpty, let expiresAt = FestivalCrewDataDTO.parseDate(inviteExpiresAt) else {
      throw FestivalCrewError.invalidResponse
    }
    return FestivalCrewInviteCode(
      code: inviteCode,
      expiresAt: expiresAt
    )
  }
}

extension FestivalCrewGatherReplyDataDTO {
  func toDomain() throws -> FestivalCrewGatherReply {
    guard !gatherId.isEmpty, !userId.isEmpty,
          let value = FestivalCrewGatherResponse(rawValue: response),
          let respondedAt = FestivalCrewDataDTO.parseDate(respondedAt) else {
      throw FestivalCrewError.invalidResponse
    }
    return FestivalCrewGatherReply(
      gatherID: gatherId,
      userID: userId,
      nickname: nickname,
      response: value,
      respondedAt: respondedAt
    )
  }
}
