public enum FestivalCatalogError: Error, Sendable {
  case invalidResponse
  case repeatedCursor
  case tooManyPages
}
