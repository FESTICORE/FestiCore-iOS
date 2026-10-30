import Foundation

enum FestivalImageUseCase {
  static func sourceValues(
    festivals: [FestivalOverview],
    selectedPack: FestivalPackDocument?
  ) -> [String] {
    let festivalValues = festivals.compactMap { $0.thumbnailURL?.absoluteString }
    let packValues = selectedPack.map { pack in
      [pack.thumbUrl].compactMap { $0 }
        + (pack.artists ?? []).compactMap(\.imageUrl)
        + pack.performances.compactMap(\.imageUrl)
    } ?? []
    var seen = Set<String>()
    return (festivalValues + packValues).filter { seen.insert($0).inserted }
  }

  static func prefetchURLs(
    festivals: [FestivalOverview],
    selectedPack: FestivalPackDocument?,
    resolvedURL: (String?) -> URL?
  ) -> [URL] {
    let packValues = selectedPack.map { pack in
      [pack.thumbUrl].compactMap(resolvedURL)
        + (pack.artists ?? []).compactMap { resolvedURL($0.imageUrl) }
        + pack.performances.compactMap { resolvedURL($0.imageUrl) }
    } ?? []
    let festivalValues = festivals.compactMap { resolvedURL($0.thumbnailURL?.absoluteString) }
    var seen = Set<URL>()
    return Array((packValues + festivalValues).filter { seen.insert($0).inserted }.prefix(100))
  }
}
