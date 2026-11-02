//
//  BearerClaimFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import BearerInterface
import ComposableArchitecture
import Foundation

/// Figma S13 F~I 기수 인증 코드. 코드 6자리를 받아 기수 권한을 등록한다.
@Reducer
public struct BearerClaimFeature {
  public init() {}

  /// 서버 코드에 쓰는 글자(I·O·0·1 제외)
  static let codeAlphabet = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
  static let codeLength = 6
  /// 서버가 남은 횟수를 주지 않을 때 쓰는 10분 안 최대 시도 횟수
  static let maxAttempts = 3

  @ObservableState
  public struct State: Equatable {
    public let festivalID: String
    public var code = ""
    public var isSubmitting = false
    public var failure: Failure?
    /// 이 화면에서 연달아 틀린 횟수. 서버가 남은 횟수를 주지 않을 때 쓴다.
    public var consecutiveFailures = 0
    public var lockedUntil: Date?
    public var now = Date()

    public init(festivalID: String) {
      self.festivalID = festivalID
    }
  }

  public enum Failure: Equatable, Sendable {
    case invalid(remainingAttempts: Int)
    case locked
    case message(String)
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
    case codeChanged(String)
    case submitTapped
    case backTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case claim(String)
    case startLockCountdown
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case claimSucceeded(BearerClaim)
    case claimFailed(BearerError)
    case lockTicked(Date)
  }

  // MARK: - DelegateAction

  /// 결과 계약은 BearerInterface에 있다.
  public typealias DelegateAction = BearerClaimDelegate

  enum CancelID {
    case claim
    case lockCountdown
  }

  @Dependency(\.bearerUseCase) private var bearerUseCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock

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

extension BearerClaimFeature.State {
  public var isLocked: Bool {
    guard let lockedUntil else { return false }
    return lockedUntil > now
  }

  public var canSubmit: Bool {
    code.count == BearerClaimFeature.codeLength && !isSubmitting && !isLocked
  }

  /// 잠금이 풀리기까지 남은 초
  public var lockRemainingSeconds: Int {
    guard let lockedUntil else { return 0 }
    return max(0, Int(lockedUntil.timeIntervalSince(now).rounded(.up)))
  }
}

extension BearerClaimFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .codeChanged(let text):
      guard !state.isSubmitting, !state.isLocked else { return .none }
      let filtered = text.uppercased().filter { Self.codeAlphabet.contains($0) }
      state.code = String(filtered.prefix(Self.codeLength))
      if case .invalid = state.failure { state.failure = nil }
      if case .message = state.failure { state.failure = nil }
      return .none

    case .submitTapped:
      state.now = date.now
      guard state.canSubmit else { return .none }
      state.isSubmitting = true
      state.failure = nil
      return .send(.async(.claim(state.code)))

    case .backTapped:
      return .send(.delegate(.closeRequested))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .claim(let code):
      let festivalID = state.festivalID
      return .run { send in
        do {
          let claim = try await bearerUseCase.claim(festivalID: festivalID, code: code)
          await send(.inner(.claimSucceeded(claim)))
        } catch let error as BearerError {
          await send(.inner(.claimFailed(error)))
        } catch {
          await send(.inner(.claimFailed(.unavailable)))
        }
      }
      .cancellable(id: CancelID.claim, cancelInFlight: true)

    case .startLockCountdown:
      return .run { send in
        for await _ in clock.timer(interval: .seconds(1)) {
          await send(.inner(.lockTicked(date.now)))
        }
      }
      .cancellable(id: CancelID.lockCountdown, cancelInFlight: true)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case .claimSucceeded(let claim):
      state.isSubmitting = false
      state.consecutiveFailures = 0
      return .send(.delegate(.claimed(festivalID: state.festivalID, claim: claim)))

    case .claimFailed(let error):
      state.isSubmitting = false
      switch error {
      case .invalidCode(let remaining):
        state.consecutiveFailures += 1
        let fallback = max(0, Self.maxAttempts - state.consecutiveFailures)
        state.failure = .invalid(remainingAttempts: remaining ?? fallback)
        return .none

      case .codeLocked(let retryAfter):
        state.now = date.now
        state.lockedUntil = state.now.addingTimeInterval(TimeInterval(retryAfter))
        state.code = ""
        state.failure = .locked
        return .send(.async(.startLockCountdown))

      default:
        state.failure = .message(Self.message(for: error))
        return .none
      }

    case .lockTicked(let now):
      state.now = now
      guard !state.isLocked else { return .none }
      state.lockedUntil = nil
      state.consecutiveFailures = 0
      state.failure = nil
      return .cancel(id: CancelID.lockCountdown)
    }
  }

  private func handleDelegateAction(
    state: inout State,
    action: DelegateAction
  ) -> Effect<Action> {
    switch action {
    case .claimed, .closeRequested:
      return .cancel(id: CancelID.lockCountdown)
    }
  }

  static func message(for error: BearerError) -> String {
    switch error {
    case .invalidRequest:
      return "코드 6자리를 다시 확인해 주세요"
    case .bearerLimit:
      return "이 페스티벌에서 이미 다른 깃발을 맡고 있어요"
    case .coBearerFull:
      return "이 깃발의 공동 기수 자리가 다 찼어요"
    case .notAuthenticated:
      return "로그인한 뒤에 입력해 주세요"
    case .termsRequired:
      return "새 약관에 동의한 뒤에 입력해 주세요"
    case .notFound:
      return "아직 공개되지 않은 페스티벌이에요"
    case .offline:
      return "인터넷에 연결되지 않았어요. 연결 후 다시 눌러 주세요"
    default:
      return "코드를 확인하지 못했어요. 잠시 후 다시 시도해 주세요"
    }
  }
}
