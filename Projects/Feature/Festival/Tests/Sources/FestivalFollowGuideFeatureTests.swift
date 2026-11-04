import ComposableArchitecture
import FestivalDomainInterface
import FestiCoreSharedUI
import Testing
@testable import Festival

@MainActor
struct FestivalFollowGuideFeatureTests {
  @Test func cancelKeepsGuideAndConfirmHidesOnlyCurrentFestival() async {
    let hidden = LockIsolated<Set<String>>([])
    let store = TestStore(initialState: FestivalFeature.State(selectedFestivalID: "festival-a")) {
      FestivalFeature()
    } withDependencies: {
      $0.festivalGuideVisibilityUseCase = MockFestivalGuideVisibilityUseCase(
        isHidden: { hidden.value.contains($0) },
        hide: { id in hidden.withValue { _ = $0.insert(id) } }
      )
    }

    await store.send(.view(.closeFollowedFlagGuideTapped)) {
      $0.alert = .hideGuide()
    }
    await store.send(.alert(.presented(.cancelTapped))) {
      $0.alert = nil
    }
    #expect(hidden.value.isEmpty)

    await store.send(.view(.closeFollowedFlagGuideTapped)) {
      $0.alert = .hideGuide()
    }
    await store.send(.alert(.presented(.confirmTapped))) {
      $0.isFollowedFlagGuideHidden = true
      $0.alert = nil
    }
    #expect(hidden.value == ["festival-a"])
  }

  @Test func previouslyHiddenGuideRestoresOnAppearAndOtherFestivalRemainsVisible() async {
    let hidden = LockIsolated<Set<String>>(["festival-a"])
    for (
      festivalID,
      expectedHidden
    ) in [("festival-a", true), ("festival-b", false)] {
      var initialState = FestivalFeature.State(selectedFestivalID: festivalID)
      initialState.hasStarted = true
      let store = TestStore(initialState: initialState) { FestivalFeature() } withDependencies: {
        $0.useServiceBackedFestivalUseCases()
        $0.festivalGuideVisibilityUseCase = MockFestivalGuideVisibilityUseCase(
          isHidden: { hidden.value.contains($0) },
          hide: { _ in }
        )
      }

      store.exhaustivity = .off
      await store.send(.view(.onAppear))
      #expect(store.state.isFollowedFlagGuideHidden == expectedHidden)
    }
  }

  @Test func findFlagsRequestsFlagTab() async {
    let store = TestStore(initialState: FestivalFeature.State(selectedFestivalID: "festival-a")) {
      FestivalFeature()
    }

    await store.send(.view(.findFlagsTapped))
    await store.receive(\.delegate.flagTabRequested)
  }
}
