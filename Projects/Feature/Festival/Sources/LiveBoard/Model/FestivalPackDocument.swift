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
  /// 기기에 저장된 팩 버전. 저장된 팩이 없으면 nil이다.
  public let cachedPackVersion: Int?
  /// 카탈로그 상태(`discovered`, `upcoming`, `live`, `ended`). 팩만 있는 항목은 nil이다.
  public let catalogStatus: String?
  /// 첫 번째 예매처 주소
  public let ticketURL: URL?

  init(item: FestivalCatalogItem, isCached: Bool, cachedPackVersion: Int? = nil) {
    id = item.id
    name = item.name
    venue = item.venue
    firstDate = item.firstDate
    lastDate = item.lastDate
    thumbnailURL = item.thumbnailURL
    packVersion = item.packVersion
    self.isCached = isCached
    self.cachedPackVersion = cachedPackVersion
    catalogStatus = item.status
    ticketURL = item.ticketLinks.first?.url
  }

  init?(pack: CachedFestivalPack) {
    guard let document = try? JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack) else {
      return nil
    }
    id = pack.festivalID
    name = document.name ?? pack.festivalID
    venue = document.venue
    let dateBounds = FestivalLiveActivitySchedule.packDateBounds(document.days ?? [])
    firstDate = dateBounds?.first
    lastDate = dateBounds?.last
    thumbnailURL = document.thumbUrl.flatMap(URL.init(string:))
    packVersion = pack.packVersion
    isCached = true
    cachedPackVersion = pack.packVersion
    catalogStatus = nil
    ticketURL = document.ticketLinks?.lazy.compactMap(\.httpsURL).first
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
  public let flagsEnabled: Bool?
  public let zones: [Zone]?
  public let source: Source?
  public let ticketLinks: [TicketLink]?

  private enum CodingKeys: String, CodingKey {
    case id, name, venue, thumbUrl, days, artists, timetable, sets, stages
    case flagsEnabled, zones, source, ticketLinks
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decodeIfPresent(String.self, forKey: .name)
    venue = try container.decodeIfPresent(String.self, forKey: .venue)
    thumbUrl = try container.decodeIfPresent(String.self, forKey: .thumbUrl)
    days = try container.decodeIfPresent([Day].self, forKey: .days)
    artists = try container.decodeIfPresent([Artist].self, forKey: .artists)
    timetable = try container.decodeIfPresent([Performance].self, forKey: .timetable)
    sets = try container.decodeIfPresent([Performance].self, forKey: .sets)
    stages = try container.decodeIfPresent([Stage].self, forKey: .stages)
    flagsEnabled = try container.decodeIfPresent(Bool.self, forKey: .flagsEnabled)
    zones = (try? container.decode([LossyZone].self, forKey: .zones))?.compactMap(\.value)
    source = try? container.decodeIfPresent(Source.self, forKey: .source)
    ticketLinks = Self.lossyTicketLinks(in: container)
  }

  /// null·형식이 다른 원소는 버리고 나머지 예매처만 읽는다.
  private static func lossyTicketLinks(in container: KeyedDecodingContainer<CodingKeys>) -> [TicketLink]? {
    guard var list = try? container.nestedUnkeyedContainer(forKey: .ticketLinks) else { return nil }
    var links: [TicketLink] = []
    while !list.isAtEnd {
      if (try? list.decodeNil()) == true { continue }
      if let link = try? list.decode(TicketLink.self) {
        links.append(link)
      } else {
        _ = try? list.decode(Skipped.self)
      }
    }
    return links
  }

  public func zoneName(for id: String?) -> String? {
    guard let id else { return nil }
    return zones?.first { $0.id == id }?.name
  }

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
    public let startsAt: String?
    public let endsAt: String?
  }

  public struct TicketLink: Decodable, Equatable {
    public let label: String
    public let url: String

    /// 이름이 있고 https인 주소만 돌려준다.
    var httpsURL: URL? {
      guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let url = URL(string: url), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
      return url
    }
  }

  private struct Skipped: Decodable {
    init(from decoder: Decoder) throws {}
  }

  public struct Zone: Decodable, Equatable {
    public let id: String
    public let name: String
  }

  private struct LossyZone: Decodable {
    let value: Zone?

    init(from decoder: Decoder) throws {
      value = try? Zone(from: decoder)
    }
  }

  public struct Source: Decodable, Equatable {
    public let name: String?
    public let url: String?
    public let verifiedAt: String?

    private enum CodingKeys: String, CodingKey {
      case name, url, verifiedAt
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      name = try? container.decodeIfPresent(String.self, forKey: .name)
      url = try? container.decodeIfPresent(String.self, forKey: .url)
      verifiedAt = try? container.decodeIfPresent(String.self, forKey: .verifiedAt)
    }
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
