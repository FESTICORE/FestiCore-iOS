import FestivalDomainInterface
import FestiCorePackInterface
import Foundation

public struct FestivalOverview: Equatable, Identifiable {
  public let id: String
  public let name: String
  public let venue: String?
  public let firstDate: String?
  public let lastDate: String?
  public let thumbnailURL: URL?
  public let packVersion: Int
  public let isCached: Bool

  init(item: FestivalCatalogItem, isCached: Bool) {
    id = item.id
    name = item.name
    venue = item.venue
    firstDate = item.firstDate
    lastDate = item.lastDate
    thumbnailURL = item.thumbnailURL
    packVersion = item.packVersion
    self.isCached = isCached
  }

  init?(pack: CachedFestivalPack) {
    guard let document = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack) else {
      return nil
    }
    id = pack.festivalID
    name = document.name ?? pack.festivalID
    venue = document.venue
    firstDate = document.days?.first?.date
    lastDate = document.days?.last?.date
    thumbnailURL = document.thumbUrl.flatMap(URL.init(string:))
    packVersion = pack.packVersion
    isCached = true
  }
}

public struct FestivalPackDocument: Decodable, Equatable {
  public let id: String
  public let name: String?
  public let venue: String?
  public let thumbUrl: String?
  public let days: [Day]?
  public let artists: [Artist]?
  public let timetable: [Performance]?
  public let sets: [Performance]?
  public let stages: [Stage]?

  public var performances: [Performance] {
    if let timetable, !timetable.isEmpty { return timetable }
    let stageNames = (stages ?? []).reduce(into: [String: String]()) { names, stage in
      if names[stage.id] == nil { names[stage.id] = stage.name }
    }
    return (sets ?? []).map { performance in
      Performance(
        id: performance.id,
        artist: performance.artist,
        stageId: performance.stageId,
        stageName: performance.stageName ?? performance.stageId.flatMap { stageNames[$0] },
        startsAt: performance.startsAt,
        endsAt: performance.endsAt,
        imageUrl: performance.imageUrl
      )
    }
  }

  public struct Day: Decodable, Equatable {
    public let date: String?
  }

  public struct Artist: Decodable, Equatable {
    public let name: String
    public let imageUrl: String?
  }

  public struct Stage: Decodable, Equatable {
    public let id: String
    public let name: String
  }

  public struct Performance: Decodable, Equatable, Identifiable {
    public let id: String
    public let artist: String?
    public let stageId: String?
    public let stageName: String?
    public let startsAt: String?
    public let endsAt: String?
    public let imageUrl: String?

    init(
      id: String,
      artist: String?,
      stageId: String?,
      stageName: String?,
      startsAt: String?,
      endsAt: String?,
      imageUrl: String?
    ) {
      self.id = id
      self.artist = artist
      self.stageId = stageId
      self.stageName = stageName
      self.startsAt = startsAt
      self.endsAt = endsAt
      self.imageUrl = imageUrl
    }
  }
}
