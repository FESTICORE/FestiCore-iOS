//
//  NicknameEditFeature.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import AuthDomainInterface
import ComposableArchitecture
import Foundation

/// 계정 화면에서 바텀시트로 띄우는 닉네임 변경. 가입 화면과 같은 1~12자 규칙을 쓴다.
@Reducer
public struct NicknameEditFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var nickname: String
    public var isSaving = false
    public var errorMessage: String?

    public init(nickname: String) {
      self.nickname = nickname
    }

    var trimmedNickname: String {
      nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
      (1 ... 12).contains(trimmedNickname.count)
    }
  }

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
    case nicknameChanged(String)
    case saveTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case save(String)
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case saved(AuthUser)
    case failed(AuthDomainError?)
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum DelegateAction: Equatable {
    case saved(AuthUser)
  }

  @Dependency(\.authUseCase) private var authUseCase

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

extension NicknameEditFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .nicknameChanged(let nickname):
      state.nickname = String(nickname.prefix(12))
      state.errorMessage = nil
      return .none

    case .saveTapped:
      guard !state.isSaving else { return .none }
      guard state.isValid else {
        state.errorMessage = "닉네임은 1~12자로 입력해 주세요."
        return .none
      }
      state.isSaving = true
      state.errorMessage = nil
      return .send(.async(.save(state.trimmedNickname)))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .save(let nickname):
      return .run { send in
        do {
          await send(.inner(.saved(try await authUseCase.updateNickname(nickname))))
        } catch {
          await send(.inner(.failed(error as? AuthDomainError)))
        }
      }
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case .saved(let user):
      state.isSaving = false
      return .send(.delegate(.saved(user)))

    case .failed(let error):
      state.isSaving = false
      state.errorMessage = error == .invalidNickname
        ? "닉네임은 1~12자로 입력해 주세요."
        : "닉네임을 바꾸지 못했어요. 다시 시도해 주세요."
      return .none
    }
  }
}
