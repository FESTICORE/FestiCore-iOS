import FestivalDomainInterface
import Foundation

extension FestivalItemDTO {
  public func toDomain(imageURL: URL?) -> FestivalCatalogItem {
    FestivalCatalogItem(
      id: id, name: name, venue: venue, firstDate: firstDate, lastDate: lastDate,
      thumbnailURL: imageURL, packVersion: packVersion, status: status
    )
  }
}
