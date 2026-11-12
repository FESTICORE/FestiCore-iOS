//
//  PinnedFlagPickerFeature.swift
//  Profile
//

import BearerDomainInterface
import ComposableArchitecture
import Foundation

/// 잠금화면에 보일 깃발을 고르는 바텀시트. 팔로우한 깃발을 읽어 하나를 고르고, 저장은 잠금화면 설정이 맡는다.
@Reducer
public struct PinnedFlagPickerFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    /// 지금 대표 깃발. nil이면 고르지 않음(가장 최근 팔로우)이다.
    public var selectedFlagID: String?
    public var followedFlags: Load = .loading

    public init(selectedFlagID: String?) {
      self.selectedFlagID = selectedFlagID
    }
  }

  /// 팔로우 목록 읽기 상태
  public enum Load: Equatable {
    case loading
    case failed
    case loaded([BearerFollowedFlag])
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
    case retryTapped
    case noneTapped
    case flagTapped(String)
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case loadFollowedFlags
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case followedFlagsLoaded([BearerFollowedFlag])
    case followedFlagsFailed
  }

  @CasePathable
  public enum DelegateAction: Equatable {
    /// nil이면 고르지 않음이다.
    case selected(BearerFollowedFlag?)
  }

  @Dependency(\.bearerUseCase) private var bearerUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )
      case let .async(asyncAction):
        return handleAsyncAction(action: asyncAction)
      case let .inner(innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction
        )
      case .delegate:
        return .none
      }
    }
  }
}

extension PinnedFlagPickerFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      guard case .loading = state.followedFlags else { return .none }
      return .send(.async(.loadFollowedFlags))

    case .retryTapped:
      state.followedFlags = .loading
      return .send(.async(.loadFollowedFlags))

    case .noneTapped:
      return .send(.delegate(.selected(nil)))

    case let .flagTapped(flagID):
      guard case let .loaded(flags) = state.followedFlags,
            let flag = flags.first(where: { $0.flagID == flagID }) else { return .none }
      return .send(.delegate(.selected(flag)))
    }
  }

  private func handleAsyncAction(action: AsyncAction) -> Effect<Action> {
    switch action {
    case .loadFollowedFlags:
      return .run { send in
        do {
          await send(.inner(.followedFlagsLoaded(try await bearerUseCase.fetchFollowedFlags(festivalID: nil))))
        } catch {
          await send(.inner(.followedFlagsFailed))
        }
      }
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .followedFlagsLoaded(flags):
      state.followedFlags = .loaded(flags)
      return .none

    case .followedFlagsFailed:
      state.followedFlags = .failed
      return .none
    }
  }
}
