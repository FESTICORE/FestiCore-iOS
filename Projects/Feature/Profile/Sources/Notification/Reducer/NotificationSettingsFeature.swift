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
    /// 서버에 보내는 중인 변경이 있는지. 한 번에 하나만 보낸다.
    public var isSaving = false
    /// 저장 중에 바뀌어 다음에 보낼 항목
    public var pendingChanges: [Kind: Bool] = [:]
    /// 지금 서버에 보내는 중인 항목
    public var savingChanges: [Kind: Bool] = [:]
    /// 서버가 마지막으로 확인해 준 설정. 저장과 재조회가 모두 실패하면 이 값으로 되돌린다.
    public var lastConfirmed: FestivalNotificationSettings?

    public init() {}

    /// 기기 설정에서 알림을 끄면 모든 토글을 꺼진 채로 보이고 바꿀 수 없다.
    /// 화면을 닫을 때 서버에 아직 반영됐다고 볼 수 없는 변경
    public var unsavedChanges: [Kind: Bool] {
      savingChanges.merging(pendingChanges) { _, pending in pending }
    }

    public var isDeviceNotificationOff: Bool {
      permission == .denied
    }
  }

  public enum Load: Equatable, Sendable {
    case loading
    case loaded
    case failed
  }

  public typealias Kind = FestivalNotificationKind

  private enum CancelID { case load, save }

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
    case save([Kind: Bool])
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(FestivalNotificationPermission, FestivalNotificationSettings?)
    case saved(FestivalNotificationSettings)
    case saveFailed
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
        return handleViewAction(
          state: &state,
          action: viewAction)

      case .async(let asyncAction):
        return handleAsyncAction(
          state: &state,
          action: asyncAction)

      case .inner(let innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction)

      case .delegate:
        return .none
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

    case let .toggled(
      kind,
      isOn):
      guard !state.isDeviceNotificationOff, let previous = state.settings, previous[kind] != isOn else {
        return .none
      }
      var updated = previous
      updated[kind] = isOn
      state.settings = updated
      state.message = nil
      state.pendingChanges[kind] = isOn
      return saveNextIfIdle(&state)
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
        await send(.inner(.loaded(
          permission,
          settings)))
      }
      .cancellable(
        id: CancelID.load,
        cancelInFlight: true)

    case .save(let changes):
      return .run { send in
        do {
          await send(.inner(.saved(try await notificationSettingsUseCase.updateSettings(changes))))
        } catch {
          await send(.inner(.saveFailed))
        }
      }
      .cancellable(id: CancelID.save)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(
      permission,
      settings):
      state.permission = permission
      // 저장 중이거나 보낼 변경이 남아 있으면 화면의 토글을 서버 값으로 덮지 않는다.
      guard !state.isSaving, state.pendingChanges.isEmpty else { return .none }
      if let settings {
        state.settings = settings
        state.lastConfirmed = settings
        state.load = .loaded
      } else if state.settings == nil {
        state.load = .failed
      }
      return .none

    case .saved(let settings):
      state.isSaving = false
      state.savingChanges = [:]
      state.lastConfirmed = settings
      // 아직 보내지 않은 변경은 화면에 남겨 두고 이어서 보낸다.
      var merged = settings
      for (
        kind,
        isOn) in state.pendingChanges { merged[kind] = isOn }
      state.settings = merged
      return saveNextIfIdle(&state)

    case .saveFailed:
      // 어느 변경까지 반영됐는지 알 수 없으니 마지막으로 확인한 값으로 되돌리고 서버 값을 다시 읽는다.
      state.isSaving = false
      state.savingChanges = [:]
      state.pendingChanges = [:]
      if let confirmed = state.lastConfirmed { state.settings = confirmed }
      state.message = "알림 설정을 저장하지 못했어요. 다시 시도해 주세요."
      return .send(.async(.load))
    }
  }

  /// 보내는 중인 요청이 없을 때만 모아 둔 변경을 한 번에 보낸다.
  private func saveNextIfIdle(_ state: inout State) -> Effect<Action> {
    guard !state.isSaving, !state.pendingChanges.isEmpty else { return .none }
    let changes = state.pendingChanges
    state.pendingChanges = [:]
    state.savingChanges = changes
    state.isSaving = true
    // 저장보다 늦게 끝난 조회가 방금 바꾼 토글을 되돌리지 않게 진행 중인 조회를 멈춘다.
    return .merge(
      .cancel(id: CancelID.load),
      .send(.async(.save(changes))))
  }
}
