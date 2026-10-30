import FestivalDomainInterface
import Foundation

public extension FestivalLiveBoardResponseDTO {
  func toEntity(
    profiles: FestivalFlagsResponseDTO,
    imageURL: (String?) -> URL?
  ) -> FestivalLiveBoardSnapshot {
    let profileByID = Dictionary(
      profiles.data.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )
    let activeFlags = data.activeFlags.map { flag in
      makeFlag(flag, profile: profileByID[flag.flagId], imageURL: imageURL)
    }
    let activeByID = Dictionary(activeFlags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let followedFlags = (data.me?.following ?? []).map { id in
      activeByID[id] ?? makeFlag(nil, id: id, profile: profileByID[id], imageURL: imageURL)
    }
    let crew = data.me?.crew.map { crew in
      FestivalLiveBoardSnapshot.Crew(
        id: crew.id,
        name: crew.name,
        members: crew.members.map {
          .init(id: $0.userId, nickname: $0.nickname, state: $0.state, zoneID: $0.zoneId)
        }
      )
    }
    return .init(festivalID: data.festivalId, activeFlags: activeFlags, followedFlags: followedFlags, crew: crew)
  }

  private func makeFlag(
    _ status: Data.Flag?,
    id: String? = nil,
    profile: FestivalFlagsResponseDTO.Data.Flag?,
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
