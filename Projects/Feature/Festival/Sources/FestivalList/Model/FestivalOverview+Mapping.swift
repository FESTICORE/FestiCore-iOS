import FestivalDomainInterface
import FestiCorePackInterface
import FestiCoreUtility
import Foundation

extension FestivalOverview {
  init(
    item: FestivalCatalogItem,
    isCached: Bool,
    cachedPackVersion: Int? = nil
  ) {
    self.init(
      id: item.id,
      name: item.name,
      venue: item.venue,
      firstDate: item.firstDate,
      lastDate: item.lastDate,
      thumbnailURL: item.thumbnailURL,
      packVersion: item.packVersion,
      isCached: isCached,
      cachedPackVersion: cachedPackVersion,
      catalogStatus: item.status,
      ticketURL: item.ticketLinks.first?.url,
      artists: item.artists
    )
  }

  init?(pack: CachedFestivalPack) {
    guard let document = try? JSONDecoder().decode(
      FestivalPackDocument.self,
      from: pack.pack
    ) else {
      return nil
    }
    let dateBounds = FestivalLiveActivitySchedule.packDateBounds(document.days ?? [])
      ?? Self.eventDateBounds(document.eventPeriod)
    self.init(
      id: pack.festivalID,
      name: document.name ?? pack.festivalID,
      venue: document.venue,
      firstDate: dateBounds?.first,
      lastDate: dateBounds?.last,
      thumbnailURL: document.thumbUrl.flatMap(URL.init(string:)),
      packVersion: pack.packVersion,
      isCached: true,
      cachedPackVersion: pack.packVersion,
      catalogStatus: nil,
      ticketURL: document.ticketLinks?.lazy.compactMap(\.httpsURL).first,
      artists: document.artists?.map {
        FestivalCatalogArtist(
          name: $0.name,
          performances: []
        )
      }
    )
  }
}

private extension FestivalOverview {
  static func eventDateBounds(
    _ period: FestivalPackDocument.EventPeriod?
  ) -> (first: String, last: String)? {
    guard let period,
          let first = period.firstDate.date(as: .day),
          let last = period.lastDate.date(as: .day),
          first <= last else { return nil }
    return (
      period.firstDate,
      period.lastDate
    )
  }
}
