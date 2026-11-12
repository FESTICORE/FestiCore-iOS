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
    let crew = me?.crew?.toDomain()
    return .init(
      festivalID: festivalId,
      activeFlags: activeFlags,
      followedFlags: followedFlags,
      crew: crew,
      serverAt: serverTime,
      pinnedFlagID: me?.pinnedFlagId,
      directoryFlags: directoryFlags,
      receivedAt: receivedAt,
      bearerFlagIDs: me?.bearerOf ?? []
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

extension FestivalLiveBoardCrewDTO {
  /// 라이브 보드와 크루 상세가 같은 크루원 존·상태 값을 쓴다.
  func toDomain() -> FestivalLiveBoardSnapshot.Crew {
    return FestivalLiveBoardSnapshot.Crew(
      id: id,
      name: name,
      members: members.map {
        .init(
          id: $0.userId,
          nickname: $0.nickname,
          state: $0.state,
          zoneID: $0.zoneId,
          updatedAt: $0.updatedAt?.isoDate
        )
      },
      ownerID: ownerId,
      gatherRequest: gatherRequest.flatMap { request in
        request.at.isoDate.map {
          .init(
            id: request.id,
            zoneID: request.zoneId,
            byUserID: request.byUserId,
            at: $0,
            expiresAt: request.expiresAt?.isoDate,
            // 모르는 응답 값이나 날짜가 틀린 응답은 그 줄만 버린다.
            responses: (request.responses ?? []).compactMap { response in
              guard let value = FestivalCrewGatherResponse(rawValue: response.response),
                    let respondedAt = response.respondedAt.isoDate else { return nil }
              return .init(
                userID: response.userId,
                nickname: response.nickname,
                response: value,
                respondedAt: respondedAt
              )
            },
            summary: request.responseSummary.map {
              .init(
                going: $0.going,
                ack: $0.ack
              )
            }
          )
        }
      },
      gatherAvailableAt: gatherAvailableAt?.isoDate
    )
  }
}
