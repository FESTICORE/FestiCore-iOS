import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalBookedStoreTests {
  private func makeStore() -> (FestivalBookedStore, UserDefaults) {
    let defaults = UserDefaults(suiteName: "FestivalBookedStoreTests.\(UUID())")!
    return (FestivalBookedStore.userDefaults(defaults), defaults)
  }

  @Test func bookmarksAreIsolatedByVerifiedUserID() {
    let (store, _) = makeStore()
    #expect(store.toggle("festival", for: "user-a") == ["festival"])
    #expect(store.load(for: "user-a") == ["festival"])
    #expect(store.load(for: "user-b").isEmpty)
    #expect(store.toggle("festival", for: "user-a").isEmpty)
    #expect(store.load(for: "user-b").isEmpty)
  }

  @Test func explicitBookmarkIntentRemainsCorrectAfterLegacyMigration() {
    let (store, defaults) = makeStore()
    defaults.set(["festival"], forKey: "FestiCore.bookedFestivalIDs")
    store.resolveLegacyMigration(accepted: true, for: "user-a")

    #expect(store.setBookmark("festival", booked: true, for: "user-a") == ["festival"])
    #expect(store.setBookmark("festival", booked: false, for: "user-a").isEmpty)
  }

  @Test func legacyBookmarksAreNotClaimedBeforeConsentAndOnlyOneUserCanClaim() {
    let (store, defaults) = makeStore()
    defaults.set(["legacy"], forKey: "FestiCore.bookedFestivalIDs")

    #expect(store.legacyBookmarks() == ["legacy"])
    #expect(store.load(for: "user-a").isEmpty)
    #expect(store.load(for: "user-b").isEmpty)

    store.resolveLegacyMigration(accepted: true, for: "user-a")
    #expect(store.load(for: "user-a") == ["legacy"])
    #expect(store.load(for: "user-b").isEmpty)
    #expect(store.legacyBookmarks().isEmpty)
    store.resolveLegacyMigration(accepted: true, for: "user-b")
    #expect(store.load(for: "user-b").isEmpty)
  }

  @Test func declinedMigrationDiscardsLegacyBookmarks() {
    let (store, defaults) = makeStore()
    defaults.set(["legacy"], forKey: "FestiCore.bookedFestivalIDs")
    store.resolveLegacyMigration(accepted: false, for: "user-a")
    #expect(store.legacyBookmarks().isEmpty)
    #expect(store.load(for: "user-a").isEmpty)
    #expect(defaults.object(forKey: "FestiCore.bookedFestivalIDs") == nil)
  }

  @Test func interruptedDeclineEventuallyClearsLegacyBookmarks() {
    let (store, defaults) = makeStore()
    defaults.set(["legacy"], forKey: "FestiCore.bookedFestivalIDs")
    defaults.set("declined", forKey: "FestiCore.bookedFestivalIDs.migrationDecision")

    #expect(store.load(for: "user-b").isEmpty)
    #expect(defaults.object(forKey: "FestiCore.bookedFestivalIDs") == nil)
  }

  @Test func interruptedAcceptedMigrationResumesOnlyForRecordedOwner() {
    let (store, defaults) = makeStore()
    defaults.set(["legacy"], forKey: "FestiCore.bookedFestivalIDs")
    defaults.set("user-a", forKey: "FestiCore.bookedFestivalIDs.migrationOwner")
    defaults.set("accepted", forKey: "FestiCore.bookedFestivalIDs.migrationDecision")

    #expect(store.load(for: "user-b").isEmpty)
    #expect(defaults.stringArray(forKey: "FestiCore.bookedFestivalIDs") == ["legacy"])
    #expect(store.load(for: "user-a") == ["legacy"])
    #expect(defaults.object(forKey: "FestiCore.bookedFestivalIDs") == nil)
  }

  @Test func interruptedBeforeDecisionCannotBeClaimedByAnotherUser() {
    let (store, defaults) = makeStore()
    defaults.set(["legacy"], forKey: "FestiCore.bookedFestivalIDs")
    defaults.set("user-a", forKey: "FestiCore.bookedFestivalIDs.migrationOwner")

    #expect(store.legacyBookmarks().isEmpty)
    store.resolveLegacyMigration(accepted: true, for: "user-b")
    #expect(store.load(for: "user-b").isEmpty)
    #expect(store.load(for: "user-a") == ["legacy"])
    #expect(defaults.string(forKey: "FestiCore.bookedFestivalIDs.migrationDecision") == "accepted")
  }

  @Test func concurrentMigrationDecisionsCanClaimLegacyForOnlyOneAccount() async {
    let (store, defaults) = makeStore()
    defaults.set(["legacy"], forKey: "FestiCore.bookedFestivalIDs")

    await withTaskGroup(of: Void.self) { group in
      group.addTask { store.resolveLegacyMigration(accepted: true, for: "user-a") }
      group.addTask { store.resolveLegacyMigration(accepted: true, for: "user-b") }
    }

    let claimedByA = store.load(for: "user-a") == ["legacy"]
    let claimedByB = store.load(for: "user-b") == ["legacy"]
    #expect(claimedByA != claimedByB)
  }

  @Test @MainActor func bookmarkTapEmitsIntentWithoutWriting() async {
    let festival = FestivalCatalogItem(id: "festival", name: "축제", packVersion: 0)
    var initial = FestivalFeature.State()
    initial.catalog = [festival]
    let store = TestStore(initialState: initial) { FestivalFeature() }

    await store.send(.view(.toggleBookedFestival("festival")))
    await store.receive(\.delegate.bookmarkRequested)
    #expect(store.state.bookedFestivalIDs.isEmpty)
  }
}
