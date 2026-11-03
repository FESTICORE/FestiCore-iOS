//
//  NoticeListFeature.swift
//  Profile
//

import ComposableArchitecture
import NoticeDomainInterface

@Reducer
public struct NoticeListFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var load = Load.idle
    public var notices: [NoticeSummary] = []
    @Presents public var destination: Destination.State?

    public init() {}
  }

  public enum Load: Equatable {
    case idle
    case loading
    case loaded
    case failed
  }

  @Reducer
  public enum Destination {
    case detail(NoticeDetailFeature)
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case destination(PresentationAction<Destination.Action>)
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
    case noticeTapped(String)
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case fetchNotices
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case noticesLoaded([NoticeSummary])
    case noticesFailed
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
        return .send(.async(.fetchNotices))

      case .view(.backTapped):
        return .send(.delegate(.backRequested))

      case .view(.retryTapped):
        guard state.load == .failed else { return .none }
        state.load = .loading
        return .send(.async(.fetchNotices))

      case let .view(.noticeTapped(id)):
        guard let notice = state.notices.first(where: { $0.id == id }) else { return .none }
        state.destination = .detail(.init(id: notice.id, title: notice.title))
        return .none

      case .async(.fetchNotices):
        return .run { send in
          do {
            await send(.inner(.noticesLoaded(try await noticeUseCase.notices())))
          } catch {
            await send(.inner(.noticesFailed))
          }
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)

      case let .inner(.noticesLoaded(notices)):
        state.notices = notices
        state.load = .loaded
        return .none

      case .inner(.noticesFailed):
        state.load = .failed
        return .none

      case .destination(.presented(.detail(.delegate(.backRequested)))):
        state.destination = nil
        return .none

      case .destination, .delegate:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension NoticeListFeature.Destination.State: Equatable {}
extension NoticeListFeature.Destination.Action: Equatable {}

private extension NoticeListFeature {
  enum CancelID { case fetch }
}
