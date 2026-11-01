import FestivalDomainInterface
import Foundation

extension FestivalItemDTO {
  public func toDomain(imageURL: URL?) -> FestivalCatalogItem {
    FestivalCatalogItem(
      id: id, name: name, venue: venue, firstDate: firstDate, lastDate: lastDate,
      thumbnailURL: imageURL, packVersion: packVersion, status: status,
      ticketLinks: (ticketLinks?.items ?? []).compactMap(\.domain)
    )
  }
}

extension FestivalTicketLinkDTO {
  /// 이름이 비었거나 https가 아닌 링크는 버린다.
  var domain: FestivalTicketLink? {
    let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !label.isEmpty, let url = URL(string: url), url.scheme?.lowercased() == "https", url.host != nil else {
      return nil
    }
    return FestivalTicketLink(label: label, url: url)
  }
}
