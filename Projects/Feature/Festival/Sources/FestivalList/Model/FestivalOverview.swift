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
  /// nil이면 서버나 캐시가 아티스트 검색 필드를 아직 제공하지 않는다.
  public let artists: [FestivalCatalogArtist]?

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
    artists = item.artists
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
    artists = nil
  }
}
