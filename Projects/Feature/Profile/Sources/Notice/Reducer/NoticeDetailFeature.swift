//
//  NoticeDetailFeature.swift
//  Profile
//

import ComposableArchitecture
import NoticeDomainInterface

@Reducer
public struct NoticeDetailFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let id: String
    public let title: String
    public var load = Load.idle
    public var detail: NoticeDetail?

    public init(id: String, title: String) {
      self.id = id
      self.title = title
    }
  }

  public enum Load: Equatable {
    case idle
    case loading
    case loaded
    case failed
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
    case retryTapped
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case fetchNotice
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case noticeLoaded(NoticeDetail)
    case noticeFailed
  }

  @CasePathable
  public enum DelegateAction: Equatable {
    case backRequested
  }

  @Dependency(\.noticeUseCase) private var noticeUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        guard state.load == .idle else { return .none }
        state.load = .loading
        return .send(.async(.fetchNotice))

      case .view(.backTapped):
        return .send(.delegate(.backRequested))

      case .view(.retryTapped):
        guard state.load == .failed else { return .none }
        state.load = .loading
        return .send(.async(.fetchNotice))

      case .async(.fetchNotice):
        let id = state.id
        return .run { send in
          do {
            await send(.inner(.noticeLoaded(try await noticeUseCase.notice(id: id))))
          } catch {
            await send(.inner(.noticeFailed))
          }
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)

      case let .inner(.noticeLoaded(detail)):
        state.detail = detail
        state.load = .loaded
        return .none

      case .inner(.noticeFailed):
        state.load = .failed
        return .none

      case .delegate:
        return .none
      }
    }
  }
}

private extension NoticeDetailFeature {
  enum CancelID { case fetch }
}
