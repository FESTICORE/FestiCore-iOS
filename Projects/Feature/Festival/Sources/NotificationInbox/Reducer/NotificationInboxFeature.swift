import ComposableArchitecture
import FestiCoreSharedUI
import Foundation
import UserNotificationDomainInterface

@Reducer
public struct NotificationInboxFeature {
  public init() {}

  public enum Load: Equatable { case idle, loading, loaded, failed }

  @ObservableState
  public struct State: Equatable {
    public let instanceID = UUID()
    public var load: Load = .idle
    public var items: [UserNotificationItem] = []
    public var nextCursor: String?
    public var isLoadingMore = false
    public var isEditing = false
    public var isDeleting = false
    public var selectedIDs: Set<String> = []
    /// 읽음 요청 중에도 화면에서는 즉시 읽음으로 보인다. 다음 목록 조회가 서버 상태로 맞춘다.
    public var locallyReadIDs: Set<String> = []
    /// 전체 재조회 후 서버가 계속 미읽음으로 보내도 같은 알림을 중복 전송하지 않는다.
    public var attemptedReadIDs: Set<String> = []
    @Presents public var alert: FCAlertState<FCAlertAction>?

    public init() {}

    public var allLoadedSelected: Bool {
      !items.isEmpty && selectedIDs.count == items.count
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case alert(PresentationAction<FCAlertAction>)
    case delegate(Delegate)
  }

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case backTapped
    case retryTapped
    case editTapped
    case cancelSelectionTapped
    case selectAllTapped
    case deleteTapped
    case rowTapped(String)
    case loadMoreTapped
    case destinationUnavailable
  }

  @CasePathable
  public enum AsyncAction: Equatable {
    case fetchPage(before: String?)
    case delete([String])
    case refreshUnreadCount
  }

  @CasePathable
  public enum InnerAction: Equatable {
    case pageLoaded(UUID, UserNotificationPage, requestedCursor: String?)
    case pageFailed(UUID, requestedCursor: String?)
    case deleteSucceeded(UUID, [String])
    case deleteFailed(UUID)
    case unreadCountLoaded(UUID, Int)
  }

  @CasePathable
  public enum Delegate: Equatable {
    case backRequested
    case rowOpened(festivalID: String?, markReadID: String?)
    case unreadCountChanged(Int)
  }

  @Dependency(\.userNotificationUseCase) private var notifications

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        guard state.load == .idle else { return .none }
        state.load = .loading
        return .send(.async(.fetchPage(before: nil)))

      case .view(.backTapped):
        return .send(.delegate(.backRequested))

      case .view(.retryTapped):
        guard state.load == .failed else { return .none }
        state.load = .loading
        return .send(.async(.fetchPage(before: nil)))

      case .view(.editTapped):
        guard state.load == .loaded, !state.items.isEmpty, !state.isLoadingMore else { return .none }
        state.isEditing = true
        return .none

      case .view(.cancelSelectionTapped):
        state.isEditing = false
        state.selectedIDs = []
        return .none

      case .view(.selectAllTapped):
        guard state.load == .loaded, state.isEditing, !state.items.isEmpty else { return .none }
        state.selectedIDs = state.allLoadedSelected ? [] : Set(state.items.map(\.id))
        return .none

      case .view(.deleteTapped):
        guard state.load == .loaded, state.isEditing, !state.items.isEmpty,
              !state.selectedIDs.isEmpty, !state.isDeleting else { return .none }
        let ids = state.items.map(\.id).filter { state.selectedIDs.contains($0) }
        guard !ids.isEmpty else { return .none }
        state.isDeleting = true
        return .send(.async(.delete(ids)))

      case let .view(.rowTapped(id)):
        guard state.load == .loaded else { return .none }
        guard let item = state.items.first(where: { $0.id == id }) else { return .none }
        if state.isEditing {
          if !state.selectedIDs.insert(id).inserted { state.selectedIDs.remove(id) }
          return .none
        }
        let shouldRead = item.readAt == nil && state.attemptedReadIDs.insert(id).inserted
        if shouldRead { state.locallyReadIDs.insert(id) }
        let festivalID = Self.liveFestivalID(for: item)
        if festivalID == nil {
          state.alert = .notificationDestinationUnavailable()
        }
        guard shouldRead || festivalID != nil else { return .none }
        return .send(.delegate(.rowOpened(festivalID: festivalID, markReadID: shouldRead ? id : nil)))

      case .view(.loadMoreTapped):
        guard state.load == .loaded, !state.isEditing,
              let cursor = state.nextCursor, !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        return .send(.async(.fetchPage(before: cursor)))

      case .view(.destinationUnavailable):
        state.alert = .notificationDestinationUnavailable()
        return .none

      case let .async(.fetchPage(before)):
        let instanceID = state.instanceID
        return .run { send in
          do {
            let page = try await notifications.notifications(before: before)
            await send(.inner(.pageLoaded(instanceID, page, requestedCursor: before)))
          } catch {
            await send(.inner(.pageFailed(instanceID, requestedCursor: before)))
          }
        }
        .cancellable(id: CancelID.page, cancelInFlight: true)

      case let .async(.delete(ids)):
        let instanceID = state.instanceID
        return .run { send in
          do {
            try await notifications.delete(ids: ids)
            await send(.inner(.deleteSucceeded(instanceID, ids)))
          } catch {
            await send(.inner(.deleteFailed(instanceID)))
          }
        }

      case .async(.refreshUnreadCount):
        let instanceID = state.instanceID
        return .run { send in
          guard let count = try? await notifications.unreadCount() else { return }
          await send(.inner(.unreadCountLoaded(instanceID, count)))
        }
        .cancellable(id: CancelID.unreadCount, cancelInFlight: true)

      case let .inner(.pageLoaded(instanceID, page, requestedCursor)):
        guard instanceID == state.instanceID else { return .none }
        if requestedCursor == nil {
          state.items = page.items
          state.locallyReadIDs = []
        } else {
          let known = Set(state.items.map(\.id))
          state.items += page.items.filter { !known.contains($0.id) }
        }
        state.selectedIDs.formIntersection(Set(state.items.map(\.id)))
        if state.items.isEmpty { state.isEditing = false }
        state.nextCursor = page.nextCursor == requestedCursor ? nil : page.nextCursor
        state.load = .loaded
        state.isLoadingMore = false
        return .none

      case let .inner(.pageFailed(instanceID, requestedCursor)):
        guard instanceID == state.instanceID else { return .none }
        state.isLoadingMore = false
        if requestedCursor == nil { state.load = .failed } else { state.alert = .notificationLoadFailed() }
        return .none

      case let .inner(.deleteSucceeded(instanceID, ids)):
        guard instanceID == state.instanceID else { return .none }
        let removed = Set(ids)
        state.items.removeAll { removed.contains($0.id) }
        state.locallyReadIDs.subtract(removed)
        state.attemptedReadIDs.subtract(removed)
        state.selectedIDs = []
        state.isEditing = false
        state.isDeleting = false
        if state.items.isEmpty, state.nextCursor != nil {
          state.load = .loading
          state.nextCursor = nil
          return .merge(.send(.async(.fetchPage(before: nil))), .send(.async(.refreshUnreadCount)))
        }
        return .send(.async(.refreshUnreadCount))

      case let .inner(.deleteFailed(instanceID)):
        guard instanceID == state.instanceID else { return .none }
        state.isDeleting = false
        state.isEditing = false
        state.selectedIDs = []
        state.load = .loading
        state.nextCursor = nil
        state.alert = .notificationDeleteFailed()
        return .merge(.send(.async(.fetchPage(before: nil))), .send(.async(.refreshUnreadCount)))

      case let .inner(.unreadCountLoaded(instanceID, count)):
        guard instanceID == state.instanceID else { return .none }
        return .send(.delegate(.unreadCountChanged(max(0, count))))

      case .alert(.presented(.confirmTapped)), .alert(.presented(.cancelTapped)):
        state.alert = nil
        return .none

      case .alert, .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert) { FCConfirmAlert() }
  }
}

private extension NotificationInboxFeature {
  enum CancelID { case page, unreadCount }

  static func liveFestivalID(for item: UserNotificationItem) -> String? {
    guard let route = item.route else { return nil }
    let parts = route.split(separator: "/", omittingEmptySubsequences: true)
    guard parts.count == 3, parts[0] == "festivals", parts[2] == "live",
          let festivalID = item.festivalID, parts[1] == festivalID else { return nil }
    return festivalID
  }
}

private extension FCAlertState where Action == FCAlertAction {
  static func notificationDestinationUnavailable() -> Self {
    .alert(title: "아직 열 수 없는 알림이에요", message: "해당 화면을 준비 중입니다.", cancelTitle: "닫기")
  }

  static func notificationLoadFailed() -> Self {
    .alert(title: "알림을 더 불러오지 못했어요", message: "잠시 후 다시 시도해 주세요.", cancelTitle: "닫기")
  }

  static func notificationDeleteFailed() -> Self {
    .alert(title: "알림을 삭제하지 못했어요", message: "연결을 확인하고 다시 시도해 주세요.", cancelTitle: "닫기")
  }
}
