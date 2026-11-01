import FestiCoreUtility
import FestivalDomainInterface
import Foundation

public extension FestivalLiveBoardDataDTO {
  func toDomain(
    profiles: FestivalFlagsDataDTO,
    imageURL: (String?) -> URL?,
    receivedAt: Date? = nil
  ) throws -> FestivalLiveBoardSnapshot {
    guard let serverTime = parseDate(serverAt) else {
      throw FestivalLiveBoardError.invalidResponse
    }
    let profileByID = Dictionary(
      profiles.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )
    let activeFlags = try self.activeFlags.map { flag in
      guard let updatedAt = parseDate(flag.updatedAt) else {
        throw FestivalLiveBoardError.invalidResponse
      }
      return makeFlag(flag, profile: profileByID[flag.flagId], imageURL: imageURL, updatedAt: updatedAt)
    }
    let activeByID = Dictionary(activeFlags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let followedFlags = (me?.following ?? []).map { id in
      activeByID[id] ?? makeFlag(nil, id: id, profile: profileByID[id], imageURL: imageURL, updatedAt: nil)
    }
    // 라이브 목록은 예정이 아닌 깃발을 최대 50개만 담는다. 상한에 닿으면 빠진 깃발의 상태를 알 수 없다.
    let missingStatus = self.activeFlags.count < Self.activeFlagLimit ? "scheduled" : "unknown"
    var seenIDs = Set<String>()
    let directoryFlags = profiles.items.compactMap { profile -> FestivalLiveBoardSnapshot.Flag? in
      guard seenIDs.insert(profile.id).inserted else { return nil }
      return activeByID[profile.id]
        ?? makeFlag(nil, id: profile.id, profile: profile, imageURL: imageURL, updatedAt: nil, status: missingStatus)
    }
    let crew = me?.crew.map { crew in
      FestivalLiveBoardSnapshot.Crew(
        id: crew.id,
        name: crew.name,
        members: crew.members.map {
          .init(
            id: $0.userId, nickname: $0.nickname, state: $0.state,
            zoneID: $0.zoneId, updatedAt: parseDate($0.updatedAt)
          )
        },
        ownerID: crew.ownerId,
        gatherRequest: crew.gatherRequest.flatMap { request in
          parseDate(request.at).map {
            .init(zoneID: request.zoneId, byUserID: request.byUserId, at: $0)
          }
        },
        gatherAvailableAt: parseDate(crew.gatherAvailableAt)
      )
    }
    return .init(
      festivalID: festivalId,
      activeFlags: activeFlags,
      followedFlags: followedFlags,
      crew: crew,
      serverAt: serverTime,
      pinnedFlagID: me?.pinnedFlagId,
      directoryFlags: directoryFlags,
      receivedAt: receivedAt
    )
  }

  private static let activeFlagLimit = 50

  private func makeFlag(
    _ status: FestivalLiveBoardFlagDTO?,
    id: String? = nil,
    profile: FestivalFlagsFlagDTO?,
    imageURL: (String?) -> URL?,
    updatedAt: Date?,
    status missingStatus: String = "unknown"
  ) -> FestivalLiveBoardSnapshot.Flag {
    .init(
      id: status?.flagId ?? id ?? "",
      name: profile?.name ?? status?.flagId ?? id ?? "깃발",
      status: status?.status ?? missingStatus,
      zoneID: status?.zoneId,
      activity: status?.activity,
      thumbnailURL: imageURL(profile?.thumbUrl),
      tags: profile?.tags ?? [],
      updatedAt: updatedAt,
      followerCount: profile?.followerCount,
      homeZoneID: profile?.homeZoneId
    )
  }

  private func parseDate(_ value: String?) -> Date? {
    value?.isoDate
  }

}
