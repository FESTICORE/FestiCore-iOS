//
//  NotificationSettingsFeature.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import UIKit

/// Figma S13 A·B 알림. 기기 알림 허용 상태와 알림 종류별 수신 여부를 다룬다.
@Reducer
public struct NotificationSettingsFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var permission: FestivalNotificationPermission?
    public var settings: FestivalNotificationSettings?
    public var load = Load.loading
    /// 저장에 실패하면 잠깐 보이는 문구
    public var message: String?

    public init() {}

    /// 기기 설정에서 알림을 끄면 모든 토글을 꺼진 채로 보이고 바꿀 수 없다.
    public var isDeviceNotificationOff: Bool {
      permission == .denied
    }
  }

  public enum Load: Equatable, Sendable {
    case loading
    case loaded
    case failed
  }

  public enum Kind: CaseIterable, Equatable, Sendable {
    case flagStatus
    case crewStatus
    case crewGather
    case setReminders
    case homecoming
    case packUpdates
  }

  private enum CancelID { case save }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case backTapped
    case retryTapped
    case openSystemSettingsTapped
    case toggled(Kind, Bool)
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case load
    case save(new: FestivalNotificationSettings, previous: FestivalNotificationSettings)
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(FestivalNotificationPermission, FestivalNotificationSettings?)
    case saved(FestivalNotificationSettings)
    case saveFailed(previous: FestivalNotificationSettings)
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum DelegateAction: Equatable {
    case backRequested
  }

  @Dependency(\.festivalNotificationSettingsUseCase) private var notificationSettingsUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case .async(let asyncAction):
        return handleAsyncAction(state: &state, action: asyncAction)

      case .inner(let innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case .delegate:
        return .none
      }
    }
  }
}

public extension FestivalNotificationSettings {
  subscript(kind: NotificationSettingsFeature.Kind) -> Bool {
    get {
      switch kind {
      case .flagStatus: flagStatus
      case .crewStatus: crewStatus
      case .crewGather: crewGather
      case .setReminders: setReminders
      case .homecoming: homecoming
      case .packUpdates: packUpdates
      }
    }
    set {
      switch kind {
      case .flagStatus: flagStatus = newValue
      case .crewStatus: crewStatus = newValue
      case .crewGather: crewGather = newValue
      case .setReminders: setReminders = newValue
      case .homecoming: homecoming = newValue
      case .packUpdates: packUpdates = newValue
      }
    }
  }
}

extension NotificationSettingsFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      // 기기 설정에서 돌아올 때마다 허용 상태를 다시 읽는다.
      if state.settings == nil { state.load = .loading }
      return .send(.async(.load))

    case .backTapped:
      return .send(.delegate(.backRequested))

    case .retryTapped:
      state.load = .loading
      return .send(.async(.load))

    case .openSystemSettingsTapped:
      return .run { _ in
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        await UIApplication.shared.open(url)
      }

    case let .toggled(kind, isOn):
      guard !state.isDeviceNotificationOff, let previous = state.settings, previous[kind] != isOn else {
        return .none
      }
      var updated = previous
      updated[kind] = isOn
      state.settings = updated
      state.message = nil
      return .send(.async(.save(new: updated, previous: previous)))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .load:
      return .run { send in
        let permission = await notificationSettingsUseCase.permission()
        let settings = try? await notificationSettingsUseCase.settings()
        await send(.inner(.loaded(permission, settings)))
      }

    case let .save(new, previous):
      return .run { send in
        do {
          await send(.inner(.saved(try await notificationSettingsUseCase.updateSettings(new))))
        } catch {
          await send(.inner(.saveFailed(previous: previous)))
        }
      }
      .cancellable(id: CancelID.save, cancelInFlight: true)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(permission, settings):
      state.permission = permission
      if let settings {
        state.settings = settings
        state.load = .loaded
      } else if state.settings == nil {
        state.load = .failed
      }
      return .none

    case .saved(let settings):
      state.settings = settings
      return .none

    case .saveFailed(let previous):
      state.settings = previous
      state.message = "알림 설정을 저장하지 못했어요. 다시 시도해 주세요."
      return .none
    }
  }
}
