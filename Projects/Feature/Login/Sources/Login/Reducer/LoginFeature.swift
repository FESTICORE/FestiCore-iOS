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
  public init() {}

  @ObservableState
  public struct State: Equatable {
    /// 로그인을 요청한 문맥. 시트 문구를 고른다.
    public enum Context: Equatable, Sendable {
      case bookmark
      case profile
      case flag
    }

    public var isSigningIn = false
    public var errorMessage: String?
    /// 부모가 선택한 탭에 맞춰 넣는다.
    public var context: Context = .bookmark
    /// 부모 흐름(예약·세션 확인)이 시트에 보여 줄 문구. 부모가 넣는다.
    public var flowMessage: String?

    public init() {}

    /// 시트 아래 안내 문구. 부모 흐름 문구를 로그인 오류보다 먼저 보여 준다.
    public var visibleMessage: String? {
      flowMessage ?? errorMessage
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
    /// 로그인 버튼 탭. 부모에게 시작을 요청한다.
    case signInTapped(OAuthProvider)
    /// 부모가 시트 상태를 확인한 뒤 보내는 로그인 시작
    case signIn(OAuthProvider)
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case signIn(OAuthProvider)
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case signInSucceeded(AuthLoginResult)
    case signInFailed(AuthDomainError)
  }

  // MARK: - DelegateAction

  /// 이동 계약은 LoginInterface에 있다.
  public typealias DelegateAction = LoginDelegate

  @Dependency(\.oauthUseCase) private var oauthUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case .async(let asyncAction):
        return handleAsyncAction(state: &state, action: asyncAction)

      case .inner(let innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case .delegate(let delegateAction):
        return handleDelegateAction(state: &state, action: delegateAction)
      }
    }
  }
}

extension LoginFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .signInTapped(let provider):
      return .send(.delegate(.signInRequested(provider)))

    case .signIn(let provider):
      guard !state.isSigningIn else { return .none }
      state.isSigningIn = true
      state.errorMessage = nil
      return .send(.async(.signIn(provider)))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .signIn(let provider):
      return .run { send in
        do {
          let result = try await oauthUseCase.signIn(provider: provider)
          await send(.inner(.signInSucceeded(result)))
        } catch let error as AuthDomainError {
          await send(.inner(.signInFailed(error)))
        } catch {
          await send(.inner(.signInFailed(.providerFailure)))
        }
      }
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case .signInSucceeded(let result):
      guard state.isSigningIn else { return .none }
      state.isSigningIn = false
      return .send(.delegate(.signedIn(result)))

    case .signInFailed(let error):
      guard state.isSigningIn else { return .none }
      state.isSigningIn = false
      switch error {
      case .userCancelled, .requestInProgress:
        state.errorMessage = nil
      default:
        state.errorMessage = "로그인에 실패했습니다. 다시 시도해 주세요."
      }
      return .none
    }
  }

  private func handleDelegateAction(
    state: inout State,
    action: DelegateAction
  ) -> Effect<Action> {
    switch action {
    case .signInRequested, .signedIn:
      return .none
    }
  }
}
