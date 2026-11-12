//
//  LockScreenSettingsFeature.swift
//  Profile
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
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
    /// 로그인하지 않았으면 '깃발' 그룹을 숨긴다. 설정 홈이 마이의 세션 상태를 넘겨 준다.
    public var hasSession: Bool
    /// Figma S13-C '잠금화면에 보일 깃발' 현재 값
    public var pinnedFlag: PinnedFlagLoad = .loading
    public var isSavingPinnedFlag = false
    @Presents public var destination: Destination.State?

    public init(hasSession: Bool = false) {
      self.hasSession = hasSession
    }
  }

  /// 대표 깃발 읽기 상태. `loaded(nil)`이면 고르지 않음(가장 최근 팔로우)이다.
  public enum PinnedFlagLoad: Equatable {
    case loading
    case failed
    case loaded(BearerPinnedFlag?)
  }

  @Reducer
  public enum Destination {
    case alert(FCConfirmAlert)
    case flagPicker(PinnedFlagPickerFeature)
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
    case destination(PresentationAction<Destination.Action>)
  }

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case backTapped
    case openSystemSettingsTapped
    case stopAllTapped
    case autoStartToggled(Bool)
    case pinnedFlagTapped
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case loadActivities
    case stopActivities([String])
    case loadPinnedFlag
    case savePinnedFlag(BearerFollowedFlag?)
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case activitiesLoaded([FestivalLiveActivityRecord])
    case activitiesStopped
    case pinnedFlagLoaded(BearerPinnedFlag?)
    case pinnedFlagFailed
    case pinnedFlagSaved(BearerFollowedFlag?)
    case pinnedFlagSaveFailed(FestivalFlagPinError)
  }

  @CasePathable
  public enum DelegateAction: Equatable {
    case backRequested
  }

  @Dependency(\.festivalLiveActivityUseCase) private var liveActivityUseCase
  @Dependency(\.openURL) private var openURL
  @Dependency(\.bearerUseCase) private var bearerUseCase
  @Dependency(\.festivalFlagDetailUseCase) private var flagDetailUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        guard !state.isStopping else { return .none }
        if !state.hasLoaded { state.isLoading = true }
        guard state.hasSession, !state.isSavingPinnedFlag else { return .send(.async(.loadActivities)) }
        return .merge(
          .send(.async(.loadActivities)),
          .send(.async(.loadPinnedFlag))
        )

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

      case .view(.pinnedFlagTapped):
        guard state.hasSession, !state.isSavingPinnedFlag else { return .none }
        let selectedFlagID: String?
        if case let .loaded(flag) = state.pinnedFlag {
          selectedFlagID = flag?.flagID
        } else {
          selectedFlagID = nil
        }
        state.destination = .flagPicker(.init(selectedFlagID: selectedFlagID))
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

      case .async(.loadPinnedFlag):
        return .run { send in
          do {
            await send(.inner(.pinnedFlagLoaded(try await bearerUseCase.fetchPinnedFlag())))
          } catch {
            await send(.inner(.pinnedFlagFailed))
          }
        }
        .cancellable(
          id: CancelID.pinnedFlag,
          cancelInFlight: true
        )

      case let .async(.savePinnedFlag(flag)):
        return .run { send in
          do {
            _ = try await flagDetailUseCase.setPinnedFlag(flag?.flagID)
            await send(.inner(.pinnedFlagSaved(flag)))
          } catch let error as FestivalFlagPinError {
            await send(.inner(.pinnedFlagSaveFailed(error)))
          } catch {
            await send(.inner(.pinnedFlagSaveFailed(.unavailable)))
          }
        }

      case let .inner(.pinnedFlagLoaded(flag)):
        state.pinnedFlag = .loaded(flag)
        return .none

      case .inner(.pinnedFlagFailed):
        // 이미 값을 보여 주고 있으면 다시 읽기 실패로 지우지 않는다.
        guard case .loading = state.pinnedFlag else { return .none }
        state.pinnedFlag = .failed
        return .none

      case let .inner(.pinnedFlagSaved(flag)):
        state.isSavingPinnedFlag = false
        state.pinnedFlag = .loaded(flag.map {
          BearerPinnedFlag(
            flagID: $0.flagID,
            name: $0.name,
            festivalID: $0.festivalID,
            thumbnailURL: $0.thumbnailURL
          )
        })
        return .none

      case let .inner(.pinnedFlagSaveFailed(error)):
        state.isSavingPinnedFlag = false
        state.destination = .alert(.pinnedFlagSaveFailed(error))
        return .none

      case let .destination(.presented(.flagPicker(.delegate(.selected(flag))))):
        state.destination = nil
        let currentFlagID: String?
        if case let .loaded(current) = state.pinnedFlag {
          currentFlagID = current?.flagID
        } else {
          currentFlagID = nil
        }
        // 같은 값을 고르면 저장하지 않는다. 읽기 전이나 실패 상태면 서버 값을 모르므로 저장한다.
        if case .loaded = state.pinnedFlag, currentFlagID == flag?.flagID { return .none }
        state.isSavingPinnedFlag = true
        return .merge(
          .cancel(id: CancelID.pinnedFlag),
          .send(.async(.savePinnedFlag(flag)))
        )

      case .destination(.presented(.alert)):
        state.destination = nil
        return .none

      case .destination, .delegate:
        return .none
      }
    }
    .ifLet(
      \.$destination,
      action: \.destination
    )
  }
}

extension LockScreenSettingsFeature.Destination.State: Equatable {}
extension LockScreenSettingsFeature.Destination.Action: Equatable {}

private extension LockScreenSettingsFeature {
  enum CancelID {
    case load
    case pinnedFlag
  }
}

extension FCAlertState where Action == FCAlertAction {
  /// 대표 깃발 저장 실패 안내. 이전 값은 그대로 둔다.
  static func pinnedFlagSaveFailed(_ error: FestivalFlagPinError) -> FCAlertState<FCAlertAction> {
    let message: String
    switch error {
    case .loginRequired: message = "다시 로그인한 뒤 골라 주세요."
    case .termsRequired: message = "약관에 다시 동의한 뒤 골라 주세요."
    case .notFollowing: message = "팔로우한 깃발만 고를 수 있어요. 팔로우를 확인해 주세요."
    case .invalidRequest, .invalidResponse, .unavailable: message = "잠시 후 다시 시도해 주세요."
    }
    return .alert(
      title: "잠금화면 깃발을 바꾸지 못했어요",
      message: message,
      confirmTitle: "확인",
      cancelTitle: "닫기"
    )
  }
}
