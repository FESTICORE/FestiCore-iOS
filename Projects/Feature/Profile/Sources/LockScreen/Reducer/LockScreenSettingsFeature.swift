//
//  LockScreenSettingsFeature.swift
//  Profile
//

import ComposableArchitecture
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
    public var activityCount = 0

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
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case loadActivities
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case activitiesLoaded(Int)
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
        if !state.hasLoaded { state.isLoading = true }
        return .send(.async(.loadActivities))

      case .view(.backTapped):
        return .send(.delegate(.backRequested))

      case .view(.openSystemSettingsTapped):
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return .none }
        return .run { _ in await openURL(url) }

      case .async(.loadActivities):
        return .run { send in
          let activities = await liveActivityUseCase.activities()
          await send(.inner(.activitiesLoaded(activities.count)))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)

      case let .inner(.activitiesLoaded(count)):
        state.activityCount = count
        state.hasLoaded = true
        state.isLoading = false
        return .none

      case .delegate:
        return .none
      }
    }
  }
}

private extension LockScreenSettingsFeature {
  enum CancelID { case load }
}
