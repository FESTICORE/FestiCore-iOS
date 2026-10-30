import FestivalDomainInterface
import Foundation

public extension FestivalLiveBoardDataDTO {
  func toDomain(
    profiles: FestivalFlagsDataDTO,
    imageURL: (String?) -> URL?
  ) -> FestivalLiveBoardSnapshot {
    let profileByID = Dictionary(
      profiles.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )
    let activeFlags = self.activeFlags.map { flag in
      makeFlag(flag, profile: profileByID[flag.flagId], imageURL: imageURL)
    }
    let activeByID = Dictionary(activeFlags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let followedFlags = (me?.following ?? []).map { id in
      activeByID[id] ?? makeFlag(nil, id: id, profile: profileByID[id], imageURL: imageURL)
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
    return .init(festivalID: festivalId, activeFlags: activeFlags, followedFlags: followedFlags, crew: crew)
  }

  private func makeFlag(
    _ status: FestivalLiveBoardFlagDTO?,
    id: String? = nil,
    profile: FestivalFlagsFlagDTO?,
    imageURL: (String?) -> URL?
  ) -> FestivalLiveBoardSnapshot.Flag {
    .init(
      id: status?.flagId ?? id ?? "",
      name: profile?.name ?? status?.flagId ?? id ?? "깃발",
      status: status?.status ?? "unknown",
      zoneID: status?.zoneId,
      activity: status?.activity,
      thumbnailURL: imageURL(profile?.thumbUrl)
    )
  }
}
