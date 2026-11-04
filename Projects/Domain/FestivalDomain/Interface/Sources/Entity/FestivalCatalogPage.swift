public struct FestivalCatalogPage: Sendable, Equatable {
  public let items: [FestivalCatalogItem]
  public let nextCursor: String?

  public init(
    items: [FestivalCatalogItem],
    nextCursor: String?
  ) {
    self.items = items
    self.nextCursor = nextCursor
  }
}
