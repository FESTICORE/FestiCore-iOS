//
//  LockScreenSettingsFeature.swift
//  Profile
//

import ComposableArchitecture
import FestiCoreStorageInterface
import FestivalDomainInterface
import Foundation
import UIKit

@Reducer
public struct LockScreenSettingsFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var isLoading = true
    public var hasLoaded = false
    public var activities: [FestivalLiveActivityRecord] = []
    public var isStopping = false
    /// Figma S13-C '당일 자동 시작'. 라이브 보드의 자동 시작이 같은 값을 읽는다.
    @Shared(.liveActivityAutoStart) public var isAutoStartOn
    public var activityCount: Int { activities.count }

    public init() {}
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case backTapped
    case openSystemSettingsTapped
    case stopAllTapped
    case autoStartToggled(Bool)
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case loadActivities
    case stopActivities([String])
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case activitiesLoaded([FestivalLiveActivityRecord])
    case activitiesStopped
  }

  @CasePathable
  public enum DelegateAction: Equatable {
    case backRequested
  }

  @Dependency(\.festivalLiveActivityUseCase) private var liveActivityUseCase
  @Dependency(\.openURL) private var openURL

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        guard !state.isStopping else { return .none }
        if !state.hasLoaded { state.isLoading = true }
        return .send(.async(.loadActivities))

      case .view(.backTapped):
        return .send(.delegate(.backRequested))

      case .view(.openSystemSettingsTapped):
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return .none }
        return .run { _ in await openURL(url) }

      case .view(.stopAllTapped):
        guard !state.isStopping, !state.activities.isEmpty else { return .none }
        state.isStopping = true
        return .merge(
          .cancel(id: CancelID.load),
          .send(.async(.stopActivities(state.activities.map(\.id))))
        )

      case let .view(.autoStartToggled(isOn)):
        state.$isAutoStartOn.withLock { $0 = isOn }
        return .none

      case .async(.loadActivities):
        return .run { send in
          let activities = await liveActivityUseCase.activities()
          await send(.inner(.activitiesLoaded(activities)))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)

      case let .async(.stopActivities(ids)):
        return .run { send in
          for id in ids { await liveActivityUseCase.end(activityID: id) }
          await send(.inner(.activitiesStopped))
        }

      case let .inner(.activitiesLoaded(activities)):
        state.activities = activities
        state.hasLoaded = true
        state.isLoading = false
        state.isStopping = false
        return .none

      case .inner(.activitiesStopped):
        return .send(.async(.loadActivities))

      case .delegate:
        return .none
      }
    }
  }
}

private extension LockScreenSettingsFeature {
  enum CancelID { case load }
}
