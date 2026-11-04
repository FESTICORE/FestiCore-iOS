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
      return FestivalCrew.Member(userID: member.userId, nickname: member.nickname, joinedAt: joinedAt)
    }
    let expiresAt: Date?
    if let inviteExpiresAt {
      guard let parsed = Self.parseDate(inviteExpiresAt) else { throw FestivalCrewError.invalidResponse }
      expiresAt = parsed
    } else {
      expiresAt = nil
    }
    return FestivalCrew(
      id: id, festivalID: festivalId, name: name, ownerID: ownerId,
      members: members, inviteCode: inviteCode, inviteExpiresAt: expiresAt
    )
  }

  private static func parseDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    return ISO8601DateFormatter().date(from: value)
  }
}
