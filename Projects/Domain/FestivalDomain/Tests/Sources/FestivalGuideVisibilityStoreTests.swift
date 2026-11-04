import Dependencies
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalGuideVisibilityStoreTests {
  @Test func hiddenGuidePersistsOnlyForSelectedFestival() throws {
    let suite = "FestiCore.guideVisibility.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = FestivalGuideVisibilityStore.userDefaults(defaults)
    #expect(!first.isHidden("festival-a"))
    first.hide("festival-a")

    let restored = FestivalGuideVisibilityStore.userDefaults(defaults)
    #expect(restored.isHidden("festival-a"))
    #expect(!restored.isHidden("festival-b"))
    restored.hide("festival-b")
    #expect(restored.isHidden("festival-a"))
    #expect(restored.isHidden("festival-b"))
  }

  @Test func useCaseUsesInjectedStore() {
    let hidden = LockIsolated<Set<String>>([])
    let useCase = withDependencies {
      $0.festivalGuideVisibilityStore = .init(
        isHidden: { hidden.value.contains($0) },
        hide: { id in hidden.withValue { _ = $0.insert(id) } }
      )
    } operation: {
      FestivalGuideVisibilityUseCaseImpl()
    }

    #expect(!useCase.isHidden(for: "festival-a"))
    useCase.hide(for: "festival-a")
    #expect(useCase.isHidden(for: "festival-a"))
    #expect(!useCase.isHidden(for: "festival-b"))
  }
}
