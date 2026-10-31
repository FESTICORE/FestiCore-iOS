import FestivalDomainInterface
import Foundation

public extension FestivalLiveBoardDataDTO {
  func toDomain(
    profiles: FestivalFlagsDataDTO,
    imageURL: (String?) -> URL?
  ) throws -> FestivalLiveBoardSnapshot {
    guard let serverTime = parseTimestamp(serverAt) else {
      throw FestivalLiveBoardError.invalidResponse
    }
    let profileByID = Dictionary(
      profiles.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )
    let activeFlags = try self.activeFlags.map { flag in
      guard let updatedAt = parseTimestamp(flag.updatedAt) else {
        throw FestivalLiveBoardError.invalidResponse
      }
      return makeFlag(flag, profile: profileByID[flag.flagId], imageURL: imageURL, updatedAt: updatedAt)
    }
    let activeByID = Dictionary(activeFlags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let followedFlags = (me?.following ?? []).map { id in
      activeByID[id] ?? makeFlag(nil, id: id, profile: profileByID[id], imageURL: imageURL, updatedAt: nil)
    }
    let crew = me?.crew.map { crew in
      FestivalLiveBoardSnapshot.Crew(
        id: crew.id,
        name: crew.name,
        members: crew.members.map {
          .init(id: $0.userId, nickname: $0.nickname, state: $0.state, zoneID: $0.zoneId)
        }
      )
    }
    return .init(
      festivalID: festivalId,
      activeFlags: activeFlags,
      followedFlags: followedFlags,
      crew: crew,
      serverAt: serverTime
    )
  }

  private func makeFlag(
    _ status: FestivalLiveBoardFlagDTO?,
    id: String? = nil,
    profile: FestivalFlagsFlagDTO?,
    imageURL: (String?) -> URL?,
    updatedAt: Date?
  ) -> FestivalLiveBoardSnapshot.Flag {
    .init(
      id: status?.flagId ?? id ?? "",
      name: profile?.name ?? status?.flagId ?? id ?? "깃발",
      status: status?.status ?? "unknown",
      zoneID: status?.zoneId,
      activity: status?.activity,
      thumbnailURL: imageURL(profile?.thumbUrl),
      updatedAt: updatedAt
    )
  }

  private func parseTimestamp(_ raw: String?) -> Date? {
    guard let raw else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: raw) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: raw)
  }
}
