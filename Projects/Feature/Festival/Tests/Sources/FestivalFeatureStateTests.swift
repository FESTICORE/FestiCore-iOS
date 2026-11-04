import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalFeatureStateTests {
  @Test func onlineDetailDisplaysWithoutSavingAnOfflinePack() throws {
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.catalog = [.init(
      id: "festival",
      name: "축제",
      packVersion: 1
    )]
    state.onlineDetailLoading = true
    #expect(state.isPackLoading)
    state.onlineDetail = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"festival","name":"온라인 축제","stages":[{"id":"main","name":"메인"}],"timetable":[{"id":"set_1","artist":"가수","stageId":"main","startsAt":"2026-11-05T10:00:00Z"}]}"#.utf8)
    )
    state.onlineDetailLoading = false

    #expect(state.selectedPack == nil)
    #expect(state.cachedPacks.isEmpty)
    #expect(state.displayDocument?.performances.first?.id == "set_1")
    #expect(!state.isPackLoading)

    state.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"festival","name":"오프라인 축제"}"#.utf8)
    )
    #expect(state.displayDocument?.name == "온라인 축제")

    state.onlineDetail = nil
    state.onlineDetailFailed = true
    #expect(state.displayDocument?.name == "오프라인 축제")
    #expect(!state.isPackLoading)
  }

  @Test func savedFestivalWinsOverCachedFallbackAndMissingSelectionDoesNot() {
    var state = FestivalFeature.State(selectedFestivalID: "missing")
    state.catalog = [
      .init(
        id: "cached",
        name: "cached",
        packVersion: 1
      ),
      .init(
        id: "saved",
        name: "saved",
        packVersion: 1
      )
    ]
    state.cachedPacks = [
      "cached": CachedFestivalPack(
        festivalID: "cached",
        packVersion: 1,
        etag: "e",
        pack: Data()
      )
    ]

    #expect(state.initialSelectedFestivalID(savedID: "saved") == "saved")
    state.selectedFestivalID = nil
    #expect(state.initialSelectedFestivalID(savedID: "missing") == "cached")
  }

  @Test func imageSourcesDeduplicateAcrossFestivalCards() {
    let image = URL(string: "https://example.com/poster.jpg")!
    var state = FestivalFeature.State()
    state.catalog = [
      .init(
        id: "one",
        name: "하나",
        thumbnailURL: image,
        packVersion: 1
      ),
      .init(
        id: "two",
        name: "둘",
        thumbnailURL: image,
        packVersion: 1
      )
    ]
    state.imageURLs = [image.absoluteString: image]

    #expect(state.imageSourceValues == [image.absoluteString])
    #expect(state.prefetchImageURLs == [image])
  }

  @Test func selectedPackImagesIncludeArtistsAndPerformances() throws {
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"""
      {"id":"festival","thumbUrl":"https://example.com/poster.webp",
      "artists":[{"name":"가수","imageUrl":"https://example.com/artist.webp"}],
      "timetable":[{"id":"set_1","imageUrl":"https://example.com/set.webp"}]}
      """#.utf8)
    )
    let urls = ["poster", "artist", "set"].map { URL(string: "https://example.com/\($0).webp")! }
    state.imageURLs = Dictionary(uniqueKeysWithValues: urls.map { ($0.absoluteString, $0) })

    #expect(state.imageSourceValues == urls.map(\.absoluteString))
    #expect(state.prefetchImageURLs == urls)
  }

  @Test func packWithoutTimetablePrefetchesSetImages() throws {
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"""
      {"id":"festival","sets":[{"id":"set_1","imageUrl":"https://example.com/set.webp"}]}
      """#.utf8)
    )
    let url = URL(string: "https://example.com/set.webp")!
    state.imageURLs = [url.absoluteString: url]

    #expect(state.imageSourceValues == [url.absoluteString])
    #expect(state.prefetchImageURLs == [url])
  }

  @Test func widgetContentUsesRealScheduleAndClearsSavedStateOnLogout() throws {
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.catalog = [.init(
      id: "festival",
      name: "축제",
      firstDate: "2026-11-05",
      lastDate: "2026-11-06",
      packVersion: 1
    )]
    state.onlineDetail = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"festival","stages":[{"id":"main","name":"메인"}],"sets":[{"id":"set_1","artist":"가수","stageId":"main","startsAt":"2026-11-05T10:00:00+09:00","endsAt":"2026-11-05T11:00:00+09:00"}]}"#.utf8)
    )
    state.hasSession = true
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: ["set_1"]
    )

    let signedIn = try #require(state.widgetContent)
    #expect(signedIn.festivalID == "festival")
    #expect(signedIn.hasPack == false)
    #expect(signedIn.performances.map(\.id) == ["set_1"])
    #expect(signedIn.performances[0].artist == "가수")
    #expect(signedIn.performances[0].stageName == "메인")
    #expect(signedIn.performances[0].isSaved)
    #expect(signedIn.performances[0].endsAt > signedIn.performances[0].startsAt)
    let comparison = try #require(state.widgetSnapshotContent)
    #expect(comparison.updatedAt == .distantPast)
    #expect(comparison == state.widgetSnapshotContent)
    let saved = comparison.withUpdatedAt(Date(timeIntervalSince1970: 1_000))
    #expect(saved.updatedAt == Date(timeIntervalSince1970: 1_000))
    #expect(saved.performances == comparison.performances)

    state.hasSession = false
    state.clearAccountData()
    #expect(state.widgetContent?.performances[0].isSaved == false)
    #expect(state.widgetContent?.crewName == nil)

    state.selectedFestivalID = nil
    #expect(state.widgetContent == nil)
  }

  @Test func widgetContentTracksPackDeletionWithoutDroppingOnlineDetail() throws {
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.catalog = [.init(
      id: "festival",
      name: "축제",
      packVersion: 1
    )]
    let document = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"festival","name":"축제"}"#.utf8)
    )
    state.selectedPack = document
    state.cachedPacks["festival"] = CachedFestivalPack(
      festivalID: "festival",
      packVersion: 1,
      etag: "e",
      pack: Data()
    )
    #expect(state.widgetContent?.hasPack == true)

    state.cachedPacks["festival"] = nil
    state.selectedPack = nil
    state.onlineDetail = document
    #expect(state.widgetContent?.hasPack == false)
    #expect(state.widgetContent?.festivalName == "축제")
  }

  @Test func widgetContentDoesNotExposeRawStageID() throws {
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.catalog = [.init(
      id: "festival",
      name: "축제",
      packVersion: 1
    )]
    state.onlineDetail = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"festival","timetable":[{"id":"set_1","artist":"가수","stageId":"stage_internal_42","startsAt":"2026-11-05T10:00:00+09:00","endsAt":"2026-11-05T11:00:00+09:00"}]}"#.utf8)
    )

    #expect(state.widgetContent?.performances.first?.stageName == "무대 정보 없음")
  }
}
