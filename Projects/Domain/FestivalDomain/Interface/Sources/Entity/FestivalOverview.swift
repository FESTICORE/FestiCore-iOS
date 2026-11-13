import Foundation

/// 축제 목록 한 줄에 쓰는 개요. 카탈로그 항목이나 기기에 저장된 팩에서 만든다.
public struct FestivalOverview: Equatable, Identifiable, Sendable {
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

  public init(
    id: String,
    name: String,
    venue: String?,
    firstDate: String?,
    lastDate: String?,
    thumbnailURL: URL?,
    packVersion: Int,
    isCached: Bool,
    cachedPackVersion: Int?,
    catalogStatus: String?,
    ticketURL: URL?,
    artists: [FestivalCatalogArtist]?
  ) {
    self.id = id
    self.name = name
    self.venue = venue
    self.firstDate = firstDate
    self.lastDate = lastDate
    self.thumbnailURL = thumbnailURL
    self.packVersion = packVersion
    self.isCached = isCached
    self.cachedPackVersion = cachedPackVersion
    self.catalogStatus = catalogStatus
    self.ticketURL = ticketURL
    self.artists = artists
  }
}
