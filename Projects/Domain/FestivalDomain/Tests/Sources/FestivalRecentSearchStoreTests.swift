import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalRecentSearchStoreTests {
  @Test func searchesAreIsolatedByAccountAndKeepNewestTen() {
    let defaults = UserDefaults(suiteName: "FestivalRecentSearchStoreTests.\(UUID())")!
    let store = FestivalRecentSearchStore.userDefaults(defaults)

    for number in 1...12 {
      _ = store.add("검색\(number)", for: "user-a")
    }
    #expect(store.load(for: "user-a").count == 10)
    #expect(store.load(for: "user-a").first == "검색12")
    #expect(store.load(for: "user-b").isEmpty)
    #expect(store.load(for: nil).isEmpty)

    #expect(store.add(" 검색11 ", for: "user-a").first == "검색11")
    #expect(store.load(for: "user-a").filter { $0 == "검색11" }.count == 1)
  }

  @Test func anonymousSearchesCanBeRemovedAndCleared() {
    let defaults = UserDefaults(suiteName: "FestivalRecentSearchStoreTests.\(UUID())")!
    let store = FestivalRecentSearchStore.userDefaults(defaults)

    #expect(store.add("펜타포트", for: nil) == ["펜타포트"])
    #expect(store.add("원더리벳", for: nil) == ["원더리벳", "펜타포트"])
    #expect(store.remove("펜타포트", for: nil) == ["원더리벳"])
    store.clear(for: nil)
    #expect(store.load(for: nil).isEmpty)
  }

  @Test func existingNewlineStorageRemainsReadable() {
    let defaults = UserDefaults(suiteName: "FestivalRecentSearchStoreTests.\(UUID())")!
    defaults.set("기존 검색\n두 번째 검색", forKey: "FestiCore.festivalRecentSearches.anonymous")
    let store = FestivalRecentSearchStore.userDefaults(defaults)

    #expect(store.load(for: nil) == ["기존 검색", "두 번째 검색"])
    #expect(store.add("새 검색", for: nil) == ["새 검색", "기존 검색", "두 번째 검색"])
  }
}
