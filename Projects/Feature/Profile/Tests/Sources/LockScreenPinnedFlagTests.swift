//
//  LockScreenPinnedFlagTests.swift
//  Profile
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import Testing
@testable import Profile

/// Figma S13-C '잠금화면에 보일 깃발' 줄과 고르기 바텀시트
@MainActor
struct LockScreenPinnedFlagTests {
  private static let pinned = BearerPinnedFlag(
    flagID: "flg_1",
    name: "호락호락",
    festivalID: "fst_1",
    thumbnailURL: nil
  )
  private static let followed = [
    BearerFollowedFlag(
      flagID: "flg_2",
      festivalID: "fst_1",
      name: "둘째 깃발",
      thumbnailURL: nil,
      followedAt: nil
    ),
    BearerFollowedFlag(
      flagID: "flg_1",
      festivalID: "fst_1",
      name: "호락호락",
      thumbnailURL: nil,
      followedAt: nil
    )
  ]

  /// 고르지 않음 상태의 바텀시트에 팔로우 목록 읽기 상태를 넣는다.
  private static func picker(_ followedFlags: PinnedFlagPickerFeature.Load) -> PinnedFlagPickerFeature.State {
    var state = PinnedFlagPickerFeature.State(selectedFlagID: nil)
    state.followedFlags = followedFlags
    return state
  }

  @Test func pinnedFlagLoadShowsFlagName() async {
    let store = TestStore(initialState: LockScreenSettingsFeature.State(hasSession: true)) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.bearerUseCase = ProfileBearerUseCase(pinnedFlag: { Self.pinned })
    }

    await store.send(.async(.loadPinnedFlag))
    await store.receive(\.inner.pinnedFlagLoaded) {
      $0.pinnedFlag = .loaded(Self.pinned)
    }
  }

  @Test func missingPinnedFlagMeansNoneSelected() async {
    let store = TestStore(initialState: LockScreenSettingsFeature.State(hasSession: true)) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.bearerUseCase = ProfileBearerUseCase(pinnedFlag: { nil })
    }

    await store.send(.async(.loadPinnedFlag))
    await store.receive(\.inner.pinnedFlagLoaded) {
      $0.pinnedFlag = .loaded(nil)
    }
  }

  @Test func pinnedFlagLoadFailureShowsFailedState() async {
    let store = TestStore(initialState: LockScreenSettingsFeature.State(hasSession: true)) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.bearerUseCase = ProfileBearerUseCase(pinnedFlag: { throw BearerError.offline })
    }

    await store.send(.async(.loadPinnedFlag))
    await store.receive(\.inner.pinnedFlagFailed) {
      $0.pinnedFlag = .failed
    }
  }

  @Test func appearLoadsPinnedFlagOnlyWithSession() async {
    let store = TestStore(initialState: LockScreenSettingsFeature.State(hasSession: true)) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(activities: { [] })
      $0.bearerUseCase = ProfileBearerUseCase(pinnedFlag: { Self.pinned })
    }
    store.exhaustivity = .off

    await store.send(.view(.onAppear))
    await store.receive(\.inner.pinnedFlagLoaded) {
      $0.pinnedFlag = .loaded(Self.pinned)
    }
  }

  @Test func signedOutHidesPickerAndSkipsPinnedFlag() async {
    let store = TestStore(initialState: LockScreenSettingsFeature.State()) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.festivalLiveActivityUseCase = MockFestivalLiveActivityUseCase(activities: { [] })
    }

    await store.send(.view(.pinnedFlagTapped))
    await store.send(.view(.onAppear))
    await store.receive(\.async.loadActivities)
    await store.receive(\.inner.activitiesLoaded) {
      $0.isLoading = false
      $0.hasLoaded = true
    }
  }

  @Test func choosingFlagSavesAndUpdatesValue() async {
    let saved = LockIsolated<[String?]>([])
    var state = LockScreenSettingsFeature.State(hasSession: true)
    state.pinnedFlag = .loaded(nil)
    let store = TestStore(initialState: state) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.bearerUseCase = ProfileBearerUseCase(followedFlags: { _ in Self.followed })
      $0.festivalFlagDetailUseCase = MockFestivalFlagDetailUseCase(setPinnedFlag: { flagID in
        saved.withValue { $0.append(flagID) }
        return flagID
      })
    }

    await store.send(.view(.pinnedFlagTapped)) {
      $0.destination = .flagPicker(.init(selectedFlagID: nil))
    }
    await store.send(.destination(.presented(.flagPicker(.view(.onAppear)))))
    await store.receive(\.destination.flagPicker.async.loadFollowedFlags)
    await store.receive(\.destination.flagPicker.inner.followedFlagsLoaded) {
      $0.destination = .flagPicker(Self.picker(.loaded(Self.followed)))
    }
    await store.send(.destination(.presented(.flagPicker(.view(.flagTapped("flg_2"))))))
    await store.receive(\.destination.flagPicker.delegate.selected) {
      $0.destination = nil
      $0.isSavingPinnedFlag = true
    }
    await store.receive(\.async.savePinnedFlag)
    await store.receive(\.inner.pinnedFlagSaved) {
      $0.isSavingPinnedFlag = false
      $0.pinnedFlag = .loaded(BearerPinnedFlag(
        flagID: "flg_2",
        name: "둘째 깃발",
        festivalID: "fst_1",
        thumbnailURL: nil
      ))
    }
    #expect(saved.value == ["flg_2"])
  }

  @Test func choosingNoneClearsPinnedFlag() async {
    let saved = LockIsolated<[String?]>([])
    var state = LockScreenSettingsFeature.State(hasSession: true)
    state.pinnedFlag = .loaded(Self.pinned)
    state.destination = .flagPicker(.init(selectedFlagID: "flg_1"))
    let store = TestStore(initialState: state) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.festivalFlagDetailUseCase = MockFestivalFlagDetailUseCase(setPinnedFlag: { flagID in
        saved.withValue { $0.append(flagID) }
        return flagID
      })
    }

    await store.send(.destination(.presented(.flagPicker(.view(.noneTapped)))))
    await store.receive(\.destination.flagPicker.delegate.selected) {
      $0.destination = nil
      $0.isSavingPinnedFlag = true
    }
    await store.receive(\.async.savePinnedFlag)
    await store.receive(\.inner.pinnedFlagSaved) {
      $0.isSavingPinnedFlag = false
      $0.pinnedFlag = .loaded(nil)
    }
    #expect(saved.value == [nil])
  }

  @Test func choosingSameFlagDoesNotSave() async {
    var state = LockScreenSettingsFeature.State(hasSession: true)
    state.pinnedFlag = .loaded(Self.pinned)
    state.destination = .flagPicker(.init(selectedFlagID: "flg_1"))
    let store = TestStore(initialState: state) {
      LockScreenSettingsFeature()
    }

    await store.send(.destination(.presented(.flagPicker(.delegate(.selected(Self.followed[1])))))) {
      $0.destination = nil
    }
  }

  @Test func saveFailureKeepsPreviousValueAndShowsAlert() async {
    var state = LockScreenSettingsFeature.State(hasSession: true)
    state.pinnedFlag = .loaded(Self.pinned)
    state.destination = .flagPicker(.init(selectedFlagID: "flg_1"))
    let store = TestStore(initialState: state) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.festivalFlagDetailUseCase = MockFestivalFlagDetailUseCase(setPinnedFlag: { _ throws(FestivalFlagPinError) in
        throw .notFollowing
      })
    }

    await store.send(.destination(.presented(.flagPicker(.delegate(.selected(Self.followed[0])))))) {
      $0.destination = nil
      $0.isSavingPinnedFlag = true
    }
    await store.receive(\.async.savePinnedFlag)
    await store.receive(\.inner.pinnedFlagSaveFailed) {
      $0.isSavingPinnedFlag = false
      $0.destination = .alert(.pinnedFlagSaveFailed(.notFollowing))
    }
    #expect(store.state.pinnedFlag == .loaded(Self.pinned))
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
    }
  }

  @Test func emptyFollowListShowsEmptyState() async {
    var state = LockScreenSettingsFeature.State(hasSession: true)
    state.destination = .flagPicker(.init(selectedFlagID: nil))
    let store = TestStore(initialState: state) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.bearerUseCase = ProfileBearerUseCase(followedFlags: { _ in [] })
    }

    await store.send(.destination(.presented(.flagPicker(.view(.onAppear)))))
    await store.receive(\.destination.flagPicker.async.loadFollowedFlags)
    await store.receive(\.destination.flagPicker.inner.followedFlagsLoaded) {
      $0.destination = .flagPicker(Self.picker(.loaded([])))
    }
  }

  @Test func followListFailureCanRetry() async {
    let calls = LockIsolated(0)
    var state = LockScreenSettingsFeature.State(hasSession: true)
    state.destination = .flagPicker(.init(selectedFlagID: nil))
    let store = TestStore(initialState: state) {
      LockScreenSettingsFeature()
    } withDependencies: {
      $0.bearerUseCase = ProfileBearerUseCase(followedFlags: { _ in
        let call = calls.withValue {
          $0 += 1
          return $0
        }
        if call == 1 { throw BearerError.offline }
        return Self.followed
      })
    }

    await store.send(.destination(.presented(.flagPicker(.view(.onAppear)))))
    await store.receive(\.destination.flagPicker.async.loadFollowedFlags)
    await store.receive(\.destination.flagPicker.inner.followedFlagsFailed) {
      $0.destination = .flagPicker(Self.picker(.failed))
    }
    await store.send(.destination(.presented(.flagPicker(.view(.retryTapped))))) {
      $0.destination = .flagPicker(Self.picker(.loading))
    }
    await store.receive(\.destination.flagPicker.async.loadFollowedFlags)
    await store.receive(\.destination.flagPicker.inner.followedFlagsLoaded) {
      $0.destination = .flagPicker(Self.picker(.loaded(Self.followed)))
    }
  }
}
