import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalUseCaseTests {
  @Test func savedFestivalWinsOverCachedFallbackAndMissingSelectionDoesNot() {
    let festivals = [
      overview("cached", cached: true),
      overview("saved", cached: false)
    ]

    #expect(FestivalCatalogUseCase.initialSelection(
      from: festivals, currentID: "missing", savedID: "saved"
    ) == "saved")
    #expect(FestivalCatalogUseCase.initialSelection(
      from: festivals, currentID: nil, savedID: "missing"
    ) == "cached")
  }

  @Test func imageSourcesDeduplicateAcrossFestivalCards() {
    let image = URL(string: "https://example.com/poster.jpg")!
    let festivals = [
      FestivalOverview(item: .init(id: "one", name: "하나", thumbnailURL: image, packVersion: 1), isCached: false),
      FestivalOverview(item: .init(id: "two", name: "둘", thumbnailURL: image, packVersion: 1), isCached: false)
    ]

    #expect(FestivalImageUseCase.sourceValues(festivals: festivals, selectedPack: nil) == [image.absoluteString])
    #expect(FestivalImageUseCase.prefetchURLs(
      festivals: festivals, selectedPack: nil,
      resolvedURL: { $0.flatMap(URL.init(string:)) }
    ) == [image])
  }

  private func overview(_ id: String, cached: Bool) -> FestivalOverview {
    FestivalOverview(item: .init(id: id, name: id, packVersion: 1), isCached: cached)
  }
}
