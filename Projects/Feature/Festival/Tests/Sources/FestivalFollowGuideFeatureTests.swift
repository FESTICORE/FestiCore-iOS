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

  @Test func liveBoardHideConfirmationPersistsCurrentFestival() async {
    let hidden = LockIsolated<Set<String>>([])
    let store = TestStore(initialState: FestivalFeature.State(selectedFestivalID: "festival-a")) {
      FestivalFeature()
    } withDependencies: {
      $0.festivalGuideVisibilityUseCase = MockFestivalGuideVisibilityUseCase(
        isHidden: { hidden.value.contains($0) },
        hide: { id in hidden.withValue { _ = $0.insert(id) } }
      )
    }
    await store.send(.view(.hideFollowGuideTapped)) {
      $0.followGuideAlert = .alert(
        title: "이 안내를 숨길까요?",
        message: "이번 페스티벌 동안 라이브 보드에서 보이지 않아요. 다시 보고 싶으면 마이 > 설정 > 라이브 보드에서 켜거나, 깃발 탭에서 언제든 깃발을 찾을 수 있어요.",
        confirmTitle: "숨기기"
      )
    }
    await store.send(.followGuideAlert(.presented(.confirmTapped))) {
      $0.hiddenFollowGuideFestivalIDs = ["festival-a"]
      $0.isFollowedFlagGuideHidden = true
      $0.followGuideAlert = nil
    }
    #expect(hidden.value == ["festival-a"])
    #expect(!store.state.showsFollowGuide)
  }

  @Test func findFlagsRequestsFlagTab() async {
    let store = TestStore(initialState: FestivalFeature.State(selectedFestivalID: "festival-a")) {
      FestivalFeature()
    }

    await store.send(.view(.findFlagsTapped))
    await store.receive(\.delegate.flagTabRequested)
  }
}
