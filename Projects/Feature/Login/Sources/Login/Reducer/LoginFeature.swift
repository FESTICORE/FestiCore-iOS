//
//  LoginFeature.swift
//  Login
//
//  Created by FestiCore on 10/29/26.
//

import AuthDomainInterface
import ComposableArchitecture
import LoginInterface

@Reducer
public struct LoginFeature {
  @Dependency(\.oauthUseCase) private var oauthUseCase

  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var isSigningIn = false
    public var errorMessage: String?

    public init() {}
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case inner(InnerAction)
    case delegate(LoginDelegate)
  }

  @CasePathable
  public enum View: Equatable {
    case signIn(OAuthProvider)
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case signInSucceeded(isNewUser: Bool)
    case signInFailed(AuthDomainError)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(.signIn(provider)):
        guard !state.isSigningIn else { return .none }
        state.isSigningIn = true
        state.errorMessage = nil
        return .run { send in
          do {
            let result = try await oauthUseCase.signIn(provider: provider)
            await send(.inner(.signInSucceeded(isNewUser: result.newUser)))
          } catch let error as AuthDomainError {
            await send(.inner(.signInFailed(error)))
          } catch {
            await send(.inner(.signInFailed(.providerFailure)))
          }
        }

      case let .inner(.signInSucceeded(isNewUser)):
        guard state.isSigningIn else { return .none }
        state.isSigningIn = false
        return .send(.delegate(.signedIn(isNewUser: isNewUser)))

      case let .inner(.signInFailed(error)):
        guard state.isSigningIn else { return .none }
        state.isSigningIn = false
        switch error {
        case .userCancelled, .requestInProgress:
          state.errorMessage = nil
        default:
          state.errorMessage = "로그인에 실패했습니다. 다시 시도해 주세요."
        }
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
