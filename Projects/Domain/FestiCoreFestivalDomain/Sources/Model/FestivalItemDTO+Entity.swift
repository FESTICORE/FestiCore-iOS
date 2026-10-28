import FestiCoreFestivalDomainInterface
import Foundation

extension FestivalItemDTO {
  public func toEntity(imageURL: URL?) -> FestivalCatalogItem {
    FestivalCatalogItem(
      id: id, name: name, venue: venue, firstDate: firstDate, lastDate: lastDate,
      thumbnailURL: imageURL, packVersion: packVersion, status: status
    )
  }
}
