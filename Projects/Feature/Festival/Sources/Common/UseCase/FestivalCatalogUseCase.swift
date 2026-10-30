import ComposableArchitecture
import FestivalDomainInterface

enum FestivalCatalogUseCase {
  static func unique(_ items: [FestivalCatalogItem]) -> IdentifiedArrayOf<FestivalCatalogItem> {
    var result: IdentifiedArrayOf<FestivalCatalogItem> = []
    for item in items where result[id: item.id] == nil {
      result.append(item)
    }
    return result
  }

  static func initialSelection(
    from festivals: [FestivalOverview],
    currentID: String?,
    savedID: String?
  ) -> String? {
    return festivals.first { $0.id == currentID }?.id
      ?? festivals.first { $0.id == savedID }?.id
      ?? festivals.first { $0.isCached }?.id
      ?? festivals.first { $0.packVersion > 0 }?.id
      ?? festivals.first?.id
  }
}
