import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalFeatureStateTests {
  @Test func savedFestivalWinsOverCachedFallbackAndMissingSelectionDoesNot() {
    var state = FestivalFeature.State(selectedFestivalID: "missing")
    state.catalog = [
      .init(id: "cached", name: "cached", packVersion: 1),
      .init(id: "saved", name: "saved", packVersion: 1)
    ]
    state.cachedPacks = [
      "cached": CachedFestivalPack(festivalID: "cached", packVersion: 1, etag: "e", pack: Data())
    ]

    #expect(state.initialSelectedFestivalID(savedID: "saved") == "saved")
    state.selectedFestivalID = nil
    #expect(state.initialSelectedFestivalID(savedID: "missing") == "cached")
  }

  @Test func imageSourcesDeduplicateAcrossFestivalCards() {
    let image = URL(string: "https://example.com/poster.jpg")!
    var state = FestivalFeature.State()
    state.catalog = [
      .init(id: "one", name: "하나", thumbnailURL: image, packVersion: 1),
      .init(id: "two", name: "둘", thumbnailURL: image, packVersion: 1)
    ]
    state.imageURLs = [image.absoluteString: image]

    #expect(state.imageSourceValues == [image.absoluteString])
    #expect(state.prefetchImageURLs == [image])
  }
}
