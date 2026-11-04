import ComposableArchitecture
import FestivalDomainInterface
import FestiCorePackInterface
import FestiCoreSharedUI
import FestivalInterface
import FestiCoreSharedUI
import Foundation
import UserNotificationDomainInterface

@Reducer
public struct FestivalFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public enum ViewState: Equatable {
      case loading
      case loaded
    }

    struct LiveActivityRuntimeState: Equatable {
      var activities: [String: FestivalLiveActivityRecord] = [:]
      var isReady = false
      var busyFestivalID: String?
      var error: String?
      var now: Date = .distantPast
      var revision = 0
    }

    public var viewState: ViewState = .loading
    public var catalog: IdentifiedArrayOf<FestivalCatalogItem> = []
    var catalogNextCursor: String?
    var isLoadingMoreCatalog = false
    public var cachedPacks: [String: CachedFestivalPack] = [:]
    public var packDownloads: [String: PackDownloadStatus] = [:]
    public var imageURLs: [String: URL] = [:]
    public var imageRevision = 0
    public var imageRetryPending = false
    public var packWatchFailed = false
    public var selectedFestivalID: String?
    /// 목록에서 연 상세 화면의 선택 정보. 디스크 캐시나 첫 페이지에 없어도 유지한다.
    var selectedCatalogItem: FestivalCatalogItem?
    public var bookedFestivalIDs: Set<String> = []
    public var bookedUserID: String?
    public var recentSearches: [String] = []
    var listInteraction = FestivalListInteractionState()
    /// 화면 하단에 2초 동안 보이는 안내. 같은 종류도 다시 표시할 수 있게 revision을 올린다.
    public var toast: Toast?
    public var toastRevision = 0
    public var selectedPack: FestivalPackDocument?
    public var homeDetails: HomeDetailsState = .idle
    public var onlineDetail: FestivalPackDocument?
    public var onlineDetailLoading = false
    public var onlineDetailFailed = false
    public var displayDocument: FestivalPackDocument? { onlineDetail ?? selectedPack }
    public var liveBoard: FestivalLiveBoardSnapshot?
    public var liveBoardUnavailable = false
    public var liveBoardUnpublished = false
    /// 현재 serverAt을 처음 받은 기기 시각. 304 응답에서도 서버 시각 보정 기준을 유지한다.
    public var liveBoardClockAnchorAt: Date?
    /// 마지막으로 라이브 보드가 정상 확인된 기기 시각. 304 응답도 포함한다.
    public var liveBoardReceivedAt: Date?
    /// 선택 축제의 빈 팔로우 깃발 안내를 숨겼는지.
    public var isFollowedFlagGuideHidden = false
    @Presents public var alert: FCAlertState<FCAlertAction>?
    public var isLiveBoardVisible = false
    /// 인증 세션이 있는지. 사용자 ID를 확인하지 못한 세션도 true다.
    public var hasSession = false
    /// 알림함의 읽지 않은 전체 알림 수. 계정이 바뀌면 즉시 비운다.
    public var notificationUnreadCount = 0
    public var hasUnreadNotifications: Bool { notificationUnreadCount > 0 }
    /// 확인된 사용자 ID. 크루의 `나` 표시에만 쓴다.
    public var sessionUserID: String?
    /// 세션이 바뀔 때마다 올려 이전 세션의 응답을 버린다.
    public var accountGeneration = 0
    public var mySchedule: MySchedule?
    public var myScheduleUnavailable = false
    @Presents public var festivalSwitcher: FestivalSwitcherFeature.State?
    @Presents public var crewCreate: FestivalCrewCreateFeature.State?
    @Presents public var followGuideAlert: FCAlertState<FCAlertAction>?
    public var hiddenFollowGuideFestivalIDs: Set<String> = []
    public var showsFollowGuide: Bool {
      !isFollowedFlagGuideHidden && (selectedFestivalID.map { !hiddenFollowGuideFestivalIDs.contains($0) } ?? false)
    }
    var myScheduleRequestID = 0
    public var connection: Connection = .loading
    public var hasStarted = false
    public var isForeground = true
    public var catalogCacheReadFailed = false
    public var catalogRefreshFailed = false
    public var packCacheReadFailed = false
    var liveActivity = LiveActivityRuntimeState()
    var autoActivityHandledStarts: [String: Date] = [:]

    public var cacheReadFailed: Bool {
      catalogCacheReadFailed || packCacheReadFailed
    }

    public init(
      selectedFestivalID: String? = nil,
      selectedCatalogItem: FestivalCatalogItem? = nil
    ) {
      self.selectedFestivalID = selectedFestivalID
      self.selectedCatalogItem = selectedCatalogItem
    }

    public var festivals: [FestivalOverview] {
      var items = catalog
      if let selectedCatalogItem, selectedCatalogItem.id == selectedFestivalID,
         items[id: selectedCatalogItem.id] == nil {
        items.append(selectedCatalogItem)
      }
      var result = items.map {
        FestivalOverview(
          item: $0,
          isCached: cachedPacks[$0.id] != nil,
          cachedPackVersion: cachedPacks[$0.id]?.packVersion
        )
      }
      let known = Set(result.map(\.id))
      result += cachedPacks.values
        .filter { !known.contains($0.festivalID) }
        .compactMap(FestivalOverview.init(pack:))
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      return result
    }

    public var selectedFestival: FestivalOverview? {
      return festivals.first { $0.id == selectedFestivalID }
    }

    /// 로그인한 사용자가 이 축제에서 맡은 깃발. 여러 개면 첫 번째를 연다.
    public var bearerFlagID: String? {
      guard hasSession, let liveBoard, liveBoard.festivalID == selectedFestivalID else { return nil }
      return liveBoard.bearerFlagIDs.first
    }

    var liveActivityState: LiveActivityControlState {
      guard let festival = selectedFestival else {
        return .init(
          title: "Live Activity 사용 불가",
          isEnabled: false,
          message: nil
        )
      }
      if liveActivity.busyFestivalID != nil {
        return .init(
          title: "처리 중",
          isEnabled: false,
          message: nil
        )
      }
      if !liveActivity.isReady {
        return .init(
          title: "Live Activity 준비 중",
          isEnabled: false,
          message: nil
        )
      }
      if liveActivity.activities[festival.id] != nil {
        return .init(
          title: "Live Activity 끄기",
          isEnabled: true,
          message: liveActivity.error
        )
      }
      guard hasSession else {
        return .init(
          title: "Live Activity 켜기",
          isEnabled: false,
          message: "로그인 후 내 공연을 저장해 주세요."
        )
      }
      guard let mySchedule, mySchedule.festivalID == festival.id else {
        return .init(
          title: "Live Activity 켜기",
          isEnabled: false,
                     message: myScheduleUnavailable ? "내 일정을 불러오지 못했습니다." : "내 일정을 불러오는 중입니다."
        )
      }
      guard !mySchedule.setIDs.isEmpty else {
        return .init(
          title: "Live Activity 켜기",
          isEnabled: false,
          message: "내 공연을 저장하면 시작 2시간 전에 자동으로 켜집니다."
        )
      }
      guard let selectedPackDocument = pack(for: festival.id) else {
        return .init(
          title: "Live Activity 켜기",
          isEnabled: false,
          message: "공연 일정을 불러오는 중입니다."
        )
      }
      guard let performanceStart = FestivalLiveActivitySchedule.nextSavedPerformanceStart(
        pack: selectedPackDocument,
        setIDs: mySchedule.setIDs,
        now: liveActivity.now
      ) else {
        return .init(
          title: "Live Activity 켜기",
          isEnabled: false,
          message: "시작 전인 저장 공연이 없습니다."
        )
      }
      guard let schedule = FestivalLiveActivitySchedule.resolve(
        festival: festival,
        pack: pack(for: festival.id),
        now: liveActivity.now
      ) else {
        return .init(
          title: "Live Activity 사용 불가",
          isEnabled: false,
          message: "축제 일정이 필요합니다."
        )
      }
      return .init(
        title: "Live Activity 켜기",
        isEnabled: schedule.phase != .finished && liveActivity.now >= performanceStart.addingTimeInterval(-7_200),
        message: liveActivity.error ?? (schedule.phase == .finished
          ? "종료된 축제입니다."
          : liveActivity.now >= performanceStart.addingTimeInterval(-7_200)
            ? "자동 시작을 기다리는 동안 직접 켤 수 있습니다."
            : "저장한 공연 시작 2시간 전에 자동으로 켜집니다.")
      )
    }

    public var showsLiveActivityControl: Bool {
      guard let festival = selectedFestival else { return false }
      if liveActivity.activities[festival.id] != nil { return true }
      guard let mySchedule, mySchedule.festivalID == festival.id,
            let pack = pack(for: festival.id), !mySchedule.setIDs.isEmpty else { return false }
      return pack.performances.contains { performance in
        guard mySchedule.setIDs.contains(performance.id),
              let start = performance.startsAt.flatMap(FestivalLiveBoardSchedule.parse),
              let end = performance.endsAt.flatMap(FestivalLiveBoardSchedule.parse) else { return false }
        return end > start
      }
    }

    /// 선택 축제의 팩을 처음 받는 중이다. 이때는 공연 영역에 빈 상태 대신 스켈레톤을 보여 준다.
    /// 오프라인·재연결 중에는 팩 서비스가 재시도만 하고 끝나지 않으므로 스켈레톤을 남기지 않는다.
    var isPackLoading: Bool {
      if displayDocument == nil, onlineDetailLoading { return true }
      if onlineDetailFailed { return false }
      guard selectedPack == nil, !packWatchFailed,
            selectedFestivalID.flatMap({ cachedPacks[$0] }) != nil else {
        return false
      }
      return connection == .loading || connection == .connecting
    }

    func pack(for festivalID: String) -> FestivalPackDocument? {
      if selectedFestivalID == festivalID { return displayDocument }
      guard let cached = cachedPacks[festivalID] else { return nil }
      return try? JSONDecoder().decode(
        FestivalPackDocument.self,
        from: cached.pack
      )
    }

    public func imageURL(for value: String?) -> URL? {
      return value.flatMap { imageURLs[$0] }
    }

    /// 로그아웃·인증 상실 때 이전 계정의 라이브 보드와 예약 목록을 비운다.
    public mutating func clearAccountData() {
      toast = nil
      liveBoard = nil
      liveBoardUnavailable = false
      liveBoardUnpublished = false
      liveBoardClockAnchorAt = nil
      liveBoardReceivedAt = nil
      alert = nil
      mySchedule = nil
      myScheduleUnavailable = false
      autoActivityHandledStarts = [:]
      bookedUserID = nil
      bookedFestivalIDs = []
      notificationUnreadCount = 0
    }
  }

  /// 서버에 저장된 내 일정 중 한 축제의 공연 ID.
  public struct MySchedule: Equatable {
    public let festivalID: String
    public let setIDs: Set<String>
  }

  public enum HomeDetailsState: Equatable {
    case idle
    case loading(String)
    case loaded(String, FestivalPackDetail.Directions?)
    case failed(String)

    public func directions(for festivalID: String) -> FestivalPackDetail.Directions? {
      guard case let .loaded(
        id,
        directions
      ) = self, id == festivalID else { return nil }
      return directions
    }
  }

  public enum Connection: Equatable {
    case loading
    case cached
    case connecting
    case reconnecting
    case live
    case offline
    case unavailable
  }

  public enum Toast: Equatable {
    case bookmarked
    case unbookmarked
    case ticketLinkMissing
    case packDownloadFailed
  }

  public enum PackDownloadStatus: Equatable {
    case downloading(PackDownloadProgress?)
  }

  struct LiveActivityControlState: Equatable {
    let title: String
    let isEnabled: Bool
    let message: String?
  }

  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case festivalSwitcher(PresentationAction<FestivalSwitcherFeature.Action>)
    case crewCreate(PresentationAction<FestivalCrewCreateFeature.Action>)
    case followGuideAlert(PresentationAction<FCAlertAction>)
    case delegate(FestivalDelegate)
    case alert(PresentationAction<FCAlertAction>)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case foregroundChanged(Bool)
    case backgrounded
    case refreshRequested
    case reloadCachedPacks
    case selectFestival(String)
    case backToFestivalList
    case toggleBookedFestival(String)
    case downloadPack(String)
    case bookmarkSaved(id: String, booked: Bool)
    case recentSearchSubmitted(String)
    case recentSearchRemoved(String)
    case recentSearchesCleared
    case searchOpened
    case searchClosed
    case searchQueryChanged(String)
    case listFilterChanged(FestivalListInteractionState.Filter)
    case loadMoreFestivals
    case liveActivityOnAppear
    case liveBoardOnAppear
    case onlineDetailOnAppear
    case liveBoardOnDisappear
    case retryMySchedule
    case retryLiveBoard
    case liveActivityTapped
    case loginTapped
    case festivalSwitchTapped
    case crewLoginTapped
    case followLoginTapped
    case createCrewTapped
    case findFlagTapped
    case hideFollowGuideTapped
    case homeDirectionsTapped
    case homeTogetherTapped
    case bearerTapped
    case notificationTapped
    case findFlagsTapped
    case closeFollowedFlagGuideTapped
    case notificationUnreadCountChanged(Int)
    case ticketLinkMissing
    /// 코디네이터가 계정·세션·내 일정 변경을 알린다.
    case reloadBookmarks(userID: String?)
    case accountChanged
    case sessionChanged(hasSession: Bool, userID: String?)
    case myScheduleSaved(festivalID: String, setIDs: Set<String>)
  }

  // MARK: - AsyncAction

  @CasePathable
  public enum AsyncAction: Equatable {
    case loadCachedFestivals
    case reloadCachedPacks
    case refresh
    case resumeForeground
    case prefetchImages
    case selectedFestivalChanged(String)
    case downloadPack(String, generation: Int)
    case startLiveActivities
    case startLiveBoard
    case loadOnlineDetail(String)
    case loadMySchedule
    case loadHomeDetails(String)
    case loadNotificationUnreadCount
    case markNotificationRead(String)
    case startLiveActivity(festivalID: String)
    case endLiveActivity(festivalID: String, activityID: String)
    case expireToast
  }

  // MARK: - InnerAction

  @CasePathable
  public enum InnerAction: Equatable {
    case cachedLoaded([FestivalCatalogItem], [CachedFestivalPack], String?, Bool, Bool)
    case cachedPacksReloaded([CachedFestivalPack])
    case catalogRefreshed([FestivalCatalogItem])
    case catalogPageLoaded(FestivalCatalogPage, after: String?)
    case catalogFailed
    case packReceived(String, PackSyncResult)
    case packFailed(String)
    case onlineDetailLoaded(String, FestivalPackDocument)
    case onlineDetailFailed(String)
    case packDownloadProgress(String, generation: Int, PackDownloadProgress)
    case packDownloadReset(String, generation: Int)
    case packDownloadFinished(String, generation: Int, PackSyncResult)
    case packDownloadFailed(String, generation: Int)
    case liveActivitiesLoaded([FestivalLiveActivityRecord], Int)
    case liveActivityStarted(FestivalLiveActivityRecord)
    case liveActivityUpdated(FestivalLiveActivityRecord)
    case liveActivityStopped(String, String)
    case liveActivityFailed(String)
    case autoStartLiveActivity(festivalID: String, performanceStart: Date)
    case liveActivityBoundary
    case liveActivityChanged
    case liveBoardLoaded(String, generation: Int, FestivalLiveBoardSnapshot)
    case liveBoardFailed(String, generation: Int)
    case liveBoardUnpublished(String, generation: Int)
    case myScheduleLoaded(festivalID: String, requestID: Int, generation: Int, Set<String>)
    case myScheduleFailed(festivalID: String, requestID: Int, generation: Int)
    case homeDetailsLoaded(String, FestivalPackDetail.Directions?)
    case homeDetailsFailed(String)
    case notificationUnreadCountLoaded(Int, generation: Int)
    case toastExpired
  }

  enum CancelID {
    case catalog, packUpdates, imagePrefetch, liveActivityChanges, liveActivityBoundary
    case liveBoard, onlineDetail, mySchedule, notificationUnreadCount, notificationMarkRead, toast
  }
  private struct LiveActivitySyncID: Hashable { let id: String }
  private struct PackDownloadID: Hashable { let id: String }

  @Dependency(\.festivalCatalogUseCase) private var catalogUseCase
  @Dependency(\.festivalPackUseCase) private var packUseCase
  @Dependency(\.festivalLibraryUseCase) private var libraryUseCase
  @Dependency(\.festivalLiveBoardUseCase) private var liveBoardUseCase
  @Dependency(\.festivalScheduleUseCase) private var scheduleUseCase
  @Dependency(\.festivalPackDetailUseCase) private var packDetailUseCase
  @Dependency(\.festivalImageUseCase) private var imageUseCase
  @Dependency(\.festivalLiveActivityUseCase) private var liveActivityUseCase
  @Dependency(\.userNotificationUseCase) var userNotificationUseCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock
  @Dependency(\.festivalGuideVisibilityUseCase) private var guideVisibilityUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case let .async(asyncAction):
        return handleAsyncAction(
          state: &state,
          action: asyncAction
        )

      case let .inner(innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction
        )

      case .alert(.presented(.confirmTapped)):
        if let festivalID = state.selectedFestivalID {
          guideVisibilityUseCase.hide(for: festivalID)
          state.isFollowedFlagGuideHidden = true
        }
        state.alert = nil
        return .none

      case .alert(.presented(.cancelTapped)), .alert(.dismiss):
        state.alert = nil
        return .none

      case let .festivalSwitcher(.presented(.delegate(delegate))):
        state.festivalSwitcher = nil
        switch delegate {
        case let .festivalSelected(id): return .send(.view(.selectFestival(id)))
        case .seeAllFestivals: return .send(.view(.backToFestivalList))
        }

      case .festivalSwitcher:
        return .none

      case .crewCreate(.presented(.delegate(.created(_)))):
        state.crewCreate = nil
        return .send(.async(.startLiveBoard))

      case .crewCreate(.presented(.delegate(.closeRequested))):
        state.crewCreate = nil
        return .none

      case .crewCreate:
        return .none

      case .followGuideAlert(.presented(.confirmTapped)):
        if let id = state.selectedFestivalID {
          state.hiddenFollowGuideFestivalIDs.insert(id)
          guideVisibilityUseCase.hide(for: id)
          state.isFollowedFlagGuideHidden = true
        }
        state.followGuideAlert = nil
        return .none

      case .followGuideAlert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(
      \.$alert,
      action: \.alert
    ) { FCConfirmAlert() }
    .ifLet(
      \.$festivalSwitcher,
      action: \.festivalSwitcher
    ) { FestivalSwitcherFeature() }
    .ifLet(
      \.$crewCreate,
      action: \.crewCreate
    ) { FestivalCrewCreateFeature() }
    .ifLet(
      \.$followGuideAlert,
      action: \.followGuideAlert
    ) { FCConfirmAlert() }
  }
}

// MARK: - 액션 처리

extension FestivalFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      state.bookedFestivalIDs = state.bookedUserID.map { libraryUseCase.bookedFestivalIDs(for: $0) } ?? []
      state.recentSearches = libraryUseCase.recentSearches(for: state.bookedUserID)
      state.isFollowedFlagGuideHidden = state.selectedFestivalID.map { guideVisibilityUseCase.isHidden(for: $0) } ?? false
      guard !state.hasStarted else { return .none }
      state.hasStarted = true
      return .send(.async(.loadCachedFestivals))

    case let .foregroundChanged(isForeground):
      state.isForeground = isForeground
      if isForeground {
        state.bookedFestivalIDs = state.bookedUserID.map { libraryUseCase.bookedFestivalIDs(for: $0) } ?? []
      }
      guard state.hasStarted else {
        return isForeground ? .send(.view(.onAppear)) : .send(.async(.prefetchImages))
      }
      if isForeground {
        state.packWatchFailed = false
        if state.liveActivity.isReady { state.liveActivity.now = date.now }
        return .send(.async(.resumeForeground))
      }
      return .merge(
        .cancel(id: CancelID.packUpdates),
        .cancel(id: CancelID.liveBoard),
        .cancel(id: CancelID.liveActivityBoundary),
        .send(.async(.prefetchImages))
      )

    case .backgrounded:
      let downloadCancels = state.packDownloads.keys.map { Effect<Action>.cancel(id: PackDownloadID(id: $0)) }
      state.packDownloads = [:]
      return .merge(downloadCancels)

    case .refreshRequested:
      state.packWatchFailed = false
      state.viewState = .loading
      state.catalogNextCursor = nil
      return .send(.async(.refresh))

    case .loadMoreFestivals:
      guard let cursor = state.catalogNextCursor, !state.isLoadingMoreCatalog,
            !state.listInteraction.isSearching, state.listInteraction.selectedFilter == .all else { return .none }
      state.isLoadingMoreCatalog = true
      return loadCatalogPage(after: cursor)

    case .reloadCachedPacks:
      return .send(.async(.reloadCachedPacks))

    case let .selectFestival(id):
      guard state.festivals.contains(where: { $0.id == id }) else { return .none }
      state.selectedFestivalID = id
      if state.selectedCatalogItem != nil, let item = state.catalog[id: id] {
        state.selectedCatalogItem = item
      }
      state.isFollowedFlagGuideHidden = guideVisibilityUseCase.isHidden(for: id)
      state.alert = nil
      state.homeDetails = .idle
      state.onlineDetail = nil
      state.onlineDetailLoading = state.isLiveBoardVisible
      state.onlineDetailFailed = false
      state.liveBoard = nil
      state.liveBoardUnavailable = false
      state.liveBoardUnpublished = false
      state.liveBoardClockAnchorAt = nil
      state.liveBoardReceivedAt = nil
      state.mySchedule = nil
      state.myScheduleUnavailable = false
      state.liveActivity.error = nil
      if state.liveActivity.isReady { state.liveActivity.now = date.now }
      state.packWatchFailed = false
      showCachedPack(in: &state)
      resolveImageURLs(in: &state)
      return .send(.async(.selectedFestivalChanged(id)))

    case .backToFestivalList:
      return .none

    case let .toggleBookedFestival(id):
      guard state.festivals.contains(where: { $0.id == id }) else { return .none }
      return .send(.delegate(.bookmarkRequested(id)))

    case let .downloadPack(id):
      guard state.isForeground,
            state.packDownloads[id] == nil,
            let festival = state.festivals.first(where: { $0.id == id }),
            festival.packVersion > 0,
            (festival.cachedPackVersion ?? -1) < festival.packVersion else { return .none }
      state.packDownloads[id] = .downloading(nil)
      return .send(.async(.downloadPack(
        id,
        generation: state.accountGeneration
      )))

    case let .bookmarkSaved(
      _,
      booked
    ):
      state.toast = booked ? .bookmarked : .unbookmarked
      state.toastRevision += 1
      return .send(.async(.expireToast))

    case let .recentSearchSubmitted(query):
      state.recentSearches = libraryUseCase.addRecentSearch(
        query,
        for: state.bookedUserID
      )
      return .none

    case let .recentSearchRemoved(query):
      state.recentSearches = libraryUseCase.removeRecentSearch(
        query,
        for: state.bookedUserID
      )
      return .none

    case .recentSearchesCleared:
      libraryUseCase.clearRecentSearches(for: state.bookedUserID)
      state.recentSearches = []
      return .none

    case .searchOpened:
      state.listInteraction.isSearching = true
      return .none

    case .searchClosed:
      state.listInteraction.isSearching = false
      state.listInteraction.query = ""
      return .none

    case let .searchQueryChanged(query):
      let wasEmpty = state.listInteraction.trimmedQuery.isEmpty
      state.listInteraction.query = query
      return wasEmpty && !state.listInteraction.trimmedQuery.isEmpty && state.catalogNextCursor != nil
        ? refreshFullCatalog() : .none

    case let .listFilterChanged(filter):
      state.listInteraction.selectedFilter = filter
      return filter == .booked && state.catalogNextCursor != nil
        ? refreshFullCatalog() : .none

    case .liveActivityOnAppear:
      return .merge(
        .send(.async(.startLiveActivities)),
        .send(.async(.loadMySchedule))
      )

    case .liveBoardOnAppear:
      state.isLiveBoardVisible = true
      state.isFollowedFlagGuideHidden = state.selectedFestivalID.map { guideVisibilityUseCase.isHidden(for: $0) } ?? false
      return .merge(
        .send(.async(.startLiveBoard)),
        state.selectedFestivalID.flatMap { state.cachedPacks[$0] == nil ? nil : $0 }
          .map { .send(.async(.loadHomeDetails($0))) } ?? .none,
        state.hasSession ? .send(.async(.loadNotificationUnreadCount)) : .none
      )

    case .onlineDetailOnAppear:
      guard let id = state.selectedFestivalID else { return .none }
      state.onlineDetailLoading = true
      state.onlineDetailFailed = false
      return .send(.async(.loadOnlineDetail(id)))

    case .liveBoardOnDisappear:
      state.isLiveBoardVisible = false
      state.onlineDetailLoading = false
      return .merge(
        .cancel(id: CancelID.liveBoard),
        .cancel(id: CancelID.onlineDetail)
      )

    case .retryMySchedule:
      return .send(.async(.loadMySchedule))

    case .retryLiveBoard:
      guard state.isLiveBoardVisible else { return .none }
      state.liveBoardUnavailable = false
      return .send(.async(.startLiveBoard))

    case .liveActivityTapped:
      guard state.liveActivity.isReady,
            let festival = state.selectedFestival,
            state.liveActivity.busyFestivalID == nil else { return .none }
      state.liveActivity.now = date.now
      state.liveActivity.error = nil
      if let existing = state.liveActivity.activities[festival.id] {
        if let mySchedule = state.mySchedule, mySchedule.festivalID == festival.id,
           let performanceStart = FestivalLiveActivitySchedule.nextSavedPerformanceStart(
             pack: state.pack(for: festival.id),
             setIDs: mySchedule.setIDs,
             now: state.liveActivity.now
           ) {
          state.autoActivityHandledStarts[festival.id] = performanceStart
        }
        state.liveActivity.busyFestivalID = festival.id
        state.liveActivity.revision += 1
        return .send(.async(.endLiveActivity(
          festivalID: festival.id,
          activityID: existing.id
        )))
      }
      guard state.liveActivityState.isEnabled else { return .none }
      state.liveActivity.busyFestivalID = festival.id
      state.liveActivity.revision += 1
      return .send(.async(.startLiveActivity(festivalID: festival.id)))

    case .loginTapped:
      return .send(.delegate(.loginRequested))

    case .festivalSwitchTapped:
      let booked = FestivalListPresentation.sorted(
        state.festivals.filter { state.bookedFestivalIDs.contains($0.id) },
        now: date.now
      )
      state.festivalSwitcher = FestivalSwitcherFeature.State(
        festivals: booked.map { festival in
          let status = FestivalListPresentation.searchBadge(
            for: festival,
            now: date.now
          )
          let subtitle = [status, festival.venue].compactMap { $0 }.joined(separator: " · ")
          return FestivalSwitcherFeature.State.Item(
            id: festival.id,
            name: festival.name,
            subtitle: subtitle,
            thumbnailURL: festival.thumbnailURL
          )
        },
        selectedFestivalID: state.selectedFestivalID
      )
      return .none

    case .crewLoginTapped:
      return .send(.delegate(.crewLoginRequested))

    case .followLoginTapped:
      return .send(.delegate(.followLoginRequested))

    case .createCrewTapped:
      guard state.hasSession else { return .send(.delegate(.crewLoginRequested)) }
      guard let festivalID = state.selectedFestivalID, state.crewCreate == nil else { return .none }
      state.crewCreate = FestivalCrewCreateFeature.State(festivalID: festivalID)
      return .none

    case .findFlagTapped:
      return .send(.delegate(.flagDirectoryRequested))

    case .homeDirectionsTapped:
      guard let festival = state.selectedFestival else { return .none }
      return .send(.delegate(.packDirectionsRequested(
        festivalID: festival.id,
        title: festival.name
      )))

    case .homeTogetherTapped:
      return .send(.view(.createCrewTapped))

    case .hideFollowGuideTapped:
      state.followGuideAlert = .alert(
        title: "이 안내를 숨길까요?",
        message: "이번 페스티벌 동안 라이브 보드에서 보이지 않아요. 다시 보고 싶으면 마이 > 설정 > 라이브 보드에서 켜거나, 깃발 탭에서 언제든 깃발을 찾을 수 있어요.",
        confirmTitle: "숨기기"
      )
      return .none

    case .bearerTapped:
      guard let festivalID = state.selectedFestival?.id, let flagID = state.bearerFlagID else { return .none }
      return .send(.delegate(.bearerBoardRequested(
        festivalID: festivalID,
        flagID: flagID,
        userID: state.sessionUserID
      )))

    case .notificationTapped:
      return .send(.delegate(state.hasSession ? .notificationInboxRequested : .loginRequested))

    case .findFlagsTapped:
      guard state.selectedFestivalID != nil else { return .none }
      return .send(.delegate(.flagTabRequested))

    case .closeFollowedFlagGuideTapped:
      guard state.selectedFestivalID != nil, !state.isFollowedFlagGuideHidden else { return .none }
      state.alert = .hideGuide()
      return .none

    case let .notificationUnreadCountChanged(count):
      guard state.hasSession else { return .none }
      state.notificationUnreadCount = max(
        0,
        count
      )
      return .none

    case .ticketLinkMissing:
      state.toast = .ticketLinkMissing
      state.toastRevision += 1
      return .send(.async(.expireToast))

    case let .reloadBookmarks(userID):
      if state.bookedUserID != userID { state.listInteraction.reset() }
      state.bookedUserID = userID
      state.bookedFestivalIDs = userID.map { libraryUseCase.bookedFestivalIDs(for: $0) } ?? []
      state.recentSearches = libraryUseCase.recentSearches(for: userID)
      return .none

    case .accountChanged:
      state.listInteraction.reset()
      // 같은 로그아웃 전환의 `sessionChanged`가 먼저 처리됐다면 라이브 보드는 이미 비우고 다시 불렀다.
      let downloadIDs = Array(state.packDownloads.keys)
      state.packDownloads = [:]
      guard state.hasSession || state.sessionUserID != nil else {
        state.bookedUserID = nil
        state.bookedFestivalIDs = []
        state.recentSearches = libraryUseCase.recentSearches(for: nil)
        return .merge(downloadIDs.map { Effect<Action>.cancel(id: PackDownloadID(id: $0)) })
      }
      state.clearAccountData()
      state.recentSearches = libraryUseCase.recentSearches(for: nil)
      state.hasSession = false
      state.sessionUserID = nil
      state.accountGeneration += 1
      return .merge(downloadIDs.map { Effect<Action>.cancel(id: PackDownloadID(id: $0)) } + [
        state.isLiveBoardVisible ? watchLiveBoard(state) : .none,
        .cancel(id: CancelID.mySchedule),
        .cancel(id: CancelID.notificationUnreadCount),
        .cancel(id: CancelID.notificationMarkRead)
      ])

    case let .sessionChanged(
      hasSession,
      userID
    ):
      guard state.hasSession != hasSession || state.sessionUserID != userID else { return .none }
      state.listInteraction.reset()
      if let bookedUserID = state.bookedUserID, bookedUserID != userID {
        state.bookedUserID = nil
        state.bookedFestivalIDs = []
      }
      state.recentSearches = libraryUseCase.recentSearches(for: state.bookedUserID)
      state.hasSession = hasSession
      let downloadIDs = Array(state.packDownloads.keys)
      state.packDownloads = [:]
      state.sessionUserID = userID
      state.notificationUnreadCount = 0
      state.accountGeneration += 1
      state.liveBoard = nil
      state.liveBoardUnavailable = false
      state.liveBoardUnpublished = false
      state.liveBoardClockAnchorAt = nil
      state.liveBoardReceivedAt = nil
      state.mySchedule = nil
      state.myScheduleUnavailable = false
      state.autoActivityHandledStarts = [:]
      return .merge(downloadIDs.map { Effect<Action>.cancel(id: PackDownloadID(id: $0)) } + [
        state.isLiveBoardVisible ? watchLiveBoard(state) : .none,
        state.liveActivity.isReady || state.isLiveBoardVisible ? loadMySchedule(&state) : .none,
        hasSession && state.isLiveBoardVisible
          ? .send(.async(.loadNotificationUnreadCount))
          : .cancel(id: CancelID.notificationUnreadCount),
        .cancel(id: CancelID.notificationMarkRead)
      ])

    case let .myScheduleSaved(
      festivalID,
      setIDs
    ):
      guard state.selectedFestivalID == festivalID,
            state.hasSession else { return .none }
      state.myScheduleRequestID += 1
      state.mySchedule = MySchedule(
        festivalID: festivalID,
        setIDs: setIDs
      )
      state.myScheduleUnavailable = false
      return .merge(
        .cancel(id: CancelID.mySchedule),
        syncLiveActivities(state)
      )
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .loadCachedFestivals:
      return .run { send in
        async let catalog = try? catalogUseCase.cachedFestivals()
        async let packs = try? packUseCase.cachedPacks()
        let cachedCatalog = await catalog
        let cachedPacks = await packs
        await send(.inner(.cachedLoaded(
          cachedCatalog ?? [],
          cachedPacks ?? [],
          catalogUseCase.savedFestivalID(),
          cachedCatalog == nil,
          cachedPacks == nil
        )))
      }

    case .reloadCachedPacks:
      return .run { send in
        if let packs = try? await packUseCase.cachedPacks() {
          await send(.inner(.cachedPacksReloaded(packs)))
        }
      }

    case .refresh:
      return .merge(
        refreshCatalog(),
        watchSelectedPack(state)
      )

    case .resumeForeground:
      return .merge(
        refreshCatalog(),
        watchSelectedPack(state),
        prefetchImages(state),
        state.liveActivity.isReady ? loadLiveActivities(revision: state.liveActivity.revision) : .none,
        state.isLiveBoardVisible ? watchLiveBoard(state) : .none,
        loadMySchedule(&state)
      )

    case .prefetchImages:
      return prefetchImages(state)

    case let .selectedFestivalChanged(id):
      return .merge(
        .run { _ in catalogUseCase.saveSelectedFestivalID(id) },
        state.isLiveBoardVisible ? .send(.async(.loadOnlineDetail(id))) : .none,
        watchSelectedPack(state),
        state.isLiveBoardVisible ? watchLiveBoard(state) : .none,
        state.isLiveBoardVisible && state.cachedPacks[id] != nil
          ? .send(.async(.loadHomeDetails(id))) : .none,
        loadMySchedule(&state),
        prefetchImages(state),
        liveActivityBoundary(state)
      )

    case let .downloadPack(
      id,
      generation
    ):
      return .run { send in
        do {
          for try await event in packUseCase.downloadPack(for: id) {
            switch event {
            case .reset:
              await send(.inner(.packDownloadReset(
                id,
                generation: generation
              )))
            case let .progress(progress):
              await send(.inner(.packDownloadProgress(
                id,
                generation: generation,
                progress
              )))
            case let .finished(result):
              await send(.inner(.packDownloadFinished(
                id,
                generation: generation,
                result
              )))
            }
          }
        } catch {
          await send(.inner(.packDownloadFailed(
            id,
            generation: generation
          )))
        }
      }
      .cancellable(
        id: PackDownloadID(id: id),
        cancelInFlight: true
      )

    case .startLiveActivities:
      return .merge(
        loadLiveActivities(revision: state.liveActivity.revision),
        watchLiveActivityChanges()
      )

    case .startLiveBoard:
      return .merge(
        watchLiveBoard(state),
        loadMySchedule(&state)
      )

    case let .loadOnlineDetail(id):
      return .run { send in
        do {
          let document = try await catalogUseCase.festivalDetail(for: id)
          await send(.inner(.onlineDetailLoaded(
            id,
            document
          )))
        } catch {
          await send(.inner(.onlineDetailFailed(id)))
        }
      }
      .cancellable(
        id: CancelID.onlineDetail,
        cancelInFlight: true
      )

    case .loadMySchedule:
      return loadMySchedule(&state)

    case let .loadHomeDetails(id):
      guard state.selectedFestivalID == id, state.cachedPacks[id] != nil else { return .none }
      state.homeDetails = .loading(id)
      return .run { send in
        do {
          let detail = try await packDetailUseCase.packDetail(festivalID: id)
          await send(.inner(.homeDetailsLoaded(
            id,
            detail?.directions
          )))
        } catch {
          await send(.inner(.homeDetailsFailed(id)))
        }
      }

    case .loadNotificationUnreadCount:
      return loadNotificationUnreadCount(state)

    case let .markNotificationRead(id):
      return markNotificationRead(
        id,
        state: state
      )

    case let .startLiveActivity(festivalID):
      guard let festival = state.festivals.first(where: { $0.id == festivalID }),
            state.hasSession,
            state.mySchedule?.festivalID == festivalID,
            let setIDs = state.mySchedule?.setIDs,
            let performanceStart = FestivalLiveActivitySchedule.nextSavedPerformanceStart(
              pack: state.pack(for: festivalID),
              setIDs: setIDs,
              now: date.now
            ),
            date.now >= performanceStart.addingTimeInterval(-7_200),
            let schedule = FestivalLiveActivitySchedule.resolve(
              festival: festival,
              pack: state.pack(for: festivalID),
              now: date.now
            ), schedule.phase != .finished else {
        // 시작할 수 없게 됐으면 버튼이 처리 중에 멈추지 않도록 잠금을 푼다.
        if state.liveActivity.busyFestivalID == festivalID { state.liveActivity.busyFestivalID = nil }
        return .none
      }
      let pack = state.pack(for: festivalID)
      return .run { send in
        do {
          let id = try await liveActivityUseCase.start(
            festivalID: festival.id,
            festivalName: festival.name,
            startDate: schedule.startDate,
            endDate: schedule.endDate,
            phase: schedule.phase
          )
          await liveActivityUseCase.update(
            activityID: id,
            phase: schedule.phase,
            startDate: schedule.startDate,
            endDate: schedule.endDate,
            pack: pack,
            savedSetIDs: setIDs
          )
          await send(.inner(.liveActivityStarted(.init(
            id: id,
            festivalID: festival.id,
            phase: schedule.phase,
            startDate: schedule.startDate,
            endDate: schedule.endDate
          ))))
        } catch {
          await send(.inner(.liveActivityFailed("Live Activity를 켤 수 없습니다. 설정을 확인해 주세요.")))
        }
      }

    case let .endLiveActivity(
      festivalID,
      activityID
    ):
      return .run { send in
        await liveActivityUseCase.end(activityID: activityID)
        await send(.inner(.liveActivityStopped(
          festivalID,
          activityID
        )))
      }

    case .expireToast:
      return .run { send in
        try await clock.sleep(for: .seconds(2))
        await send(.inner(.toastExpired))
      }
      .cancellable(
        id: CancelID.toast,
        cancelInFlight: true
      )
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .cachedLoaded(
      catalog,
      packs,
      savedID,
      catalogReadFailed,
      packReadFailed
    ):
      state.catalog = State.uniqueCatalog(catalog)
      state.cachedPacks = Dictionary(uniqueKeysWithValues: packs.map { ($0.festivalID, $0) })
      if !state.festivals.isEmpty { state.viewState = .loaded }
      state.catalogCacheReadFailed = catalogReadFailed
      state.packCacheReadFailed = packReadFailed
      state.selectedFestivalID = state.initialSelectedFestivalID(savedID: savedID)
      state.isFollowedFlagGuideHidden = state.selectedFestivalID.map { guideVisibilityUseCase.isHidden(for: $0) } ?? false
      showCachedPack(in: &state)
      resolveImageURLs(in: &state)
      let detail = loadOnlineDetailIfNeeded(&state)
      return .merge(
        refreshCatalog(),
        watchSelectedPack(state),
        prefetchImages(state),
        syncLiveActivities(state),
        loadMySchedule(&state),
        detail
      )

    case let .cachedPacksReloaded(packs):
      state.cachedPacks = Dictionary(uniqueKeysWithValues: packs.map { ($0.festivalID, $0) })
      state.packCacheReadFailed = false
      showCachedPack(in: &state)
      resolveImageURLs(in: &state)
      return .merge(
        watchSelectedPack(state),
        prefetchImages(state),
        syncLiveActivities(state)
      )

    case let .catalogRefreshed(catalog):
      state.viewState = .loaded
      state.catalogRefreshFailed = false
      let hasMoreCatalogPages = state.catalogNextCursor != nil
      state.catalogNextCursor = nil
      state.isLoadingMoreCatalog = false
      if state.liveActivity.isReady { state.liveActivity.now = date.now }
      let previouslyAvailable = (state.selectedFestival?.packVersion ?? 0) > 0
      let restartFailedWatch = state.packWatchFailed
      state.packWatchFailed = false
      state.catalog = State.uniqueCatalog(catalog)
      if state.selectedCatalogItem != nil, let id = state.selectedFestivalID,
         let item = state.catalog[id: id] {
        state.selectedCatalogItem = item
      }
      retryImagesAfterRecovery(in: &state)
      state.catalogCacheReadFailed = false
      if state.selectedFestival == nil, (state.selectedFestivalID == nil || !hasMoreCatalogPages),
         let first = state.festivals.first(where: { $0.isCached || $0.packVersion > 0 }) ?? state.festivals.first {
        state.selectedFestivalID = first.id
        state.isFollowedFlagGuideHidden = guideVisibilityUseCase.isHidden(for: first.id)
        state.onlineDetail = nil
        showCachedPack(in: &state)
        resolveImageURLs(in: &state)
        let detail = loadOnlineDetailIfNeeded(&state)
        return .merge(
          watchSelectedPack(state),
          prefetchImages(state),
          syncLiveActivities(state),
          loadMySchedule(&state),
          detail
        )
      }
      resolveImageURLs(in: &state)
      if state.selectedPack == nil, state.selectedFestival?.packVersion == 0 {
        state.connection = .unavailable
      }
      let prefetch = prefetchImages(state)
      return (restartFailedWatch || !previouslyAvailable) && (state.selectedFestival?.packVersion ?? 0) > 0
        ? .merge(
          watchSelectedPack(state),
          prefetch,
          syncLiveActivities(state)
        )
        : .merge(
          prefetch,
          syncLiveActivities(state)
        )

    case let .catalogPageLoaded(
      page,
      after
    ):
      guard after == nil || after == state.catalogNextCursor else { return .none }
      let items = after == nil ? page.items : Array(state.catalog) + page.items
      // Preserve a saved selection until the final page confirms it is absent.
      state.catalogNextCursor = page.nextCursor
      let effects = handleInnerAction(
        state: &state,
        action: .catalogRefreshed(items)
      )
      state.catalogNextCursor = page.nextCursor
      state.isLoadingMoreCatalog = false
      return page.nextCursor != nil &&
        (!state.listInteraction.trimmedQuery.isEmpty || state.listInteraction.selectedFilter == .booked)
        ? .merge(
          effects,
          refreshFullCatalog()
        ) : effects

    case .catalogFailed:
      state.viewState = .loaded
      state.catalogRefreshFailed = true
      state.isLoadingMoreCatalog = false
      if state.connection != .live {
        state.imageRetryPending = true
        state.connection = .offline
      }
      return .none

    case let .packReceived(
      id,
      result
    ):
      guard state.selectedFestivalID == id else { return .none }
      switch result {
      case let .updated(pack), let .notModified(pack):
        let previousPack = state.selectedPack
        let previousPackData = state.cachedPacks[id]?.pack
        state.cachedPacks[id] = pack
        if let document = try? JSONDecoder().decode(
          FestivalPackDocument.self,
          from: pack.pack
        ) {
          state.selectedPack = document
          state.connection = .live
          state.packWatchFailed = false
          state.packCacheReadFailed = false
          let retryPending = state.imageRetryPending
          retryImagesAfterRecovery(in: &state)
          resolveImageURLs(in: &state)
          let refreshHome = state.isLiveBoardVisible && previousPackData != pack.pack
            ? Effect<Action>.send(.async(.loadHomeDetails(id))) : .none
          return previousPack != document || retryPending
            ? .merge(
              prefetchImages(state),
              syncLiveActivities(state),
              refreshHome
            )
            : refreshHome
        } else {
          state.connection = state.selectedPack == nil ? .unavailable : .cached
        }
      case .retryAfter:
        state.connection = state.selectedPack == nil ? .connecting : .cached
      case .reconnecting:
        state.connection = .reconnecting
        state.imageRetryPending = true
      }
      return .none

    case let .onlineDetailLoaded(
      id,
      document
    ):
      guard state.selectedFestivalID == id else { return .none }
      guard document.id == id else {
        state.onlineDetailLoading = false
        state.onlineDetailFailed = true
        return .none
      }
      state.onlineDetail = document
      state.onlineDetailLoading = false
      state.onlineDetailFailed = false
      resolveImageURLs(in: &state)
      return .merge(
        prefetchImages(state),
        syncLiveActivities(state)
      )

    case let .onlineDetailFailed(id):
      guard state.selectedFestivalID == id, state.isLiveBoardVisible else { return .none }
      state.onlineDetailLoading = false
      state.onlineDetailFailed = true
      return .none

    case let .packFailed(id):
      guard state.selectedFestivalID == id else { return .none }
      state.imageRetryPending = true
      state.packWatchFailed = true
      state.connection = .offline
      return .none

    case let .packDownloadProgress(
      id,
      generation,
      progress
    ):
      guard generation == state.accountGeneration, state.packDownloads.keys.contains(id) else { return .none }
      state.packDownloads[id] = .downloading(progress)
      return .none

    case let .packDownloadReset(
      id,
      generation
    ):
      guard generation == state.accountGeneration, state.packDownloads.keys.contains(id) else { return .none }
      state.packDownloads[id] = .downloading(nil)
      return .none

    case let .packDownloadFinished(
      id,
      generation,
      result
    ):
      guard generation == state.accountGeneration, state.packDownloads.keys.contains(id) else { return .none }
      state.packDownloads.removeValue(forKey: id)
      switch result {
      case let .updated(pack), let .notModified(pack):
        if state.selectedFestivalID == id {
          let received = handleInnerAction(
            state: &state,
            action: .packReceived(
            id,
            result
          )
          )
          return .merge(
            received,
            watchSelectedPack(state)
          )
        }
        state.cachedPacks[id] = pack
        return .none
      case .retryAfter, .reconnecting:
        state.toast = .packDownloadFailed
        state.toastRevision += 1
        return .send(.async(.expireToast))
      }

    case let .packDownloadFailed(
      id,
      generation
    ):
      guard generation == state.accountGeneration, state.packDownloads.keys.contains(id) else { return .none }
      state.packDownloads.removeValue(forKey: id)
      state.toast = .packDownloadFailed
      state.toastRevision += 1
      return .send(.async(.expireToast))

    case let .liveBoardLoaded(
      id,
      generation,
      snapshot
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      if state.liveBoard?.serverAt != snapshot.serverAt || state.liveBoardClockAnchorAt == nil {
        state.liveBoardClockAnchorAt = date.now
      }
      state.liveBoard = snapshot
      state.liveBoardUnavailable = false
      state.liveBoardUnpublished = false
      state.liveBoardReceivedAt = date.now
      return .none

    case let .liveBoardUnpublished(
      id,
      generation
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      state.liveBoard = nil
      state.liveBoardUnavailable = false
      state.liveBoardUnpublished = true
      state.liveBoardClockAnchorAt = nil
      state.liveBoardReceivedAt = nil
      return .none

    case let .liveBoardFailed(
      id,
      generation
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      state.liveBoardUnavailable = true
      return .none

    case let .myScheduleLoaded(
      festivalID,
      requestID,
      generation,
      setIDs
    ):
      guard state.selectedFestivalID == festivalID,
            state.myScheduleRequestID == requestID,
            state.accountGeneration == generation,
            state.hasSession else { return .none }
      state.mySchedule = MySchedule(
        festivalID: festivalID,
        setIDs: setIDs
      )
      state.myScheduleUnavailable = false
      let detail = state.liveActivity.isReady && state.pack(for: festivalID) == nil && !setIDs.isEmpty
        ? Effect<Action>.send(.async(.loadOnlineDetail(festivalID))) : .none
      return .merge(
        syncLiveActivities(state),
        detail
      )

    case let .myScheduleFailed(
      festivalID,
      requestID,
      generation
    ):
      guard state.selectedFestivalID == festivalID,
            state.myScheduleRequestID == requestID,
            state.accountGeneration == generation,
            state.hasSession else { return .none }
      state.myScheduleUnavailable = true
      return .none

    case let .homeDetailsLoaded(
      id,
      directions
    ):
      guard state.selectedFestivalID == id else { return .none }
      state.homeDetails = .loaded(
        id,
        directions
      )
      return .none

    case let .homeDetailsFailed(id):
      guard state.selectedFestivalID == id else { return .none }
      state.homeDetails = .failed(id)
      return .none

    case let .notificationUnreadCountLoaded(
      count,
      generation
    ):
      guard state.hasSession, state.accountGeneration == generation else { return .none }
      state.notificationUnreadCount = max(
        0,
        count
      )
      return .none

    case let .liveActivitiesLoaded(
      activities,
      revision
    ):
      guard revision == state.liveActivity.revision else {
        return loadLiveActivities(revision: state.liveActivity.revision)
      }
      state.liveActivity.isReady = true
      state.liveActivity.now = date.now
      var current: [String: FestivalLiveActivityRecord] = [:]
      for activity in activities where current[activity.festivalID] == nil {
        current[activity.festivalID] = activity
      }
      if let busyID = state.liveActivity.busyFestivalID {
        current[busyID] = state.liveActivity.activities[busyID]
      }
      state.liveActivity.activities = current
      return syncLiveActivities(state)

    case let .liveActivityStarted(activity):
      state.liveActivity.busyFestivalID = nil
      state.liveActivity.revision += 1
      state.liveActivity.activities[activity.festivalID] = activity
      return liveActivityBoundary(state)

    case let .liveActivityUpdated(activity):
      guard state.liveActivity.activities[activity.festivalID]?.id == activity.id else { return .none }
      state.liveActivity.activities[activity.festivalID] = activity
      return .none

    case let .liveActivityStopped(
      festivalID,
      activityID
    ):
      if state.liveActivity.busyFestivalID == festivalID {
        state.liveActivity.busyFestivalID = nil
      }
      state.liveActivity.revision += 1
      if state.liveActivity.activities[festivalID]?.id == activityID {
        state.liveActivity.activities.removeValue(forKey: festivalID)
      }
      return liveActivityBoundary(state)

    case let .liveActivityFailed(message):
      state.liveActivity.busyFestivalID = nil
      state.liveActivity.revision += 1
      state.liveActivity.error = message
      return .none

    case let .autoStartLiveActivity(
      festivalID,
      performanceStart
    ):
      guard state.isForeground, state.liveActivity.isReady, state.hasSession,
            state.selectedFestivalID == festivalID,
            state.mySchedule?.festivalID == festivalID,
            state.liveActivity.activities[festivalID] == nil,
            state.liveActivity.busyFestivalID == nil,
            state.autoActivityHandledStarts[festivalID] != performanceStart,
            let setIDs = state.mySchedule?.setIDs,
            let nextStart = FestivalLiveActivitySchedule.nextSavedPerformanceStart(
              pack: state.pack(for: festivalID),
              setIDs: setIDs,
              now: date.now
            ), nextStart == performanceStart,
            date.now >= performanceStart.addingTimeInterval(-7_200) else { return .none }
      state.autoActivityHandledStarts[festivalID] = performanceStart
      state.liveActivity.busyFestivalID = festivalID
      state.liveActivity.revision += 1
      return .send(.async(.startLiveActivity(festivalID: festivalID)))

    case .liveActivityBoundary:
      state.liveActivity.now = date.now
      return syncLiveActivities(state)

    case .liveActivityChanged:
      return loadLiveActivities(revision: state.liveActivity.revision)

    case .toastExpired:
      state.toast = nil
      return .none
    }
  }
}

// MARK: - 효과

extension FestivalFeature {
  private func refreshCatalog() -> Effect<Action> {
    return .run { send in
      do {
        let page = try await catalogUseCase.festivalPage(
          after: nil,
          limit: 10
        )
        if page.nextCursor == nil {
          await send(.inner(.catalogRefreshed(page.items)))
        } else {
          await send(.inner(.catalogPageLoaded(
            page,
            after: nil
          )))
        }
      }
      catch { await send(.inner(.catalogFailed)) }
    }
    .cancellable(
      id: CancelID.catalog,
      cancelInFlight: true
    )
  }

  private func loadCatalogPage(after: String) -> Effect<Action> {
    return .run { send in
      do {
        let page = try await catalogUseCase.festivalPage(
          after: after,
          limit: 10
        )
        await send(.inner(.catalogPageLoaded(
          page,
          after: after
        )))
      } catch {
        await send(.inner(.catalogFailed))
      }
    }
    .cancellable(
      id: CancelID.catalog,
      cancelInFlight: true
    )
  }

  private func refreshFullCatalog() -> Effect<Action> {
    return .run { send in
      do { await send(.inner(.catalogRefreshed(try await catalogUseCase.refreshFestivals()))) }
      catch { await send(.inner(.catalogFailed)) }
    }
    .cancellable(
      id: CancelID.catalog,
      cancelInFlight: true
    )
  }

  private func loadLiveActivities(revision: Int) -> Effect<Action> {
    return .run { send in
      await send(.inner(.liveActivitiesLoaded(
        await liveActivityUseCase.activities(),
        revision
      )))
    }
  }

  private func watchLiveActivityChanges() -> Effect<Action> {
    return .run { send in
      for await _ in liveActivityUseCase.activityChanges() {
        await send(.inner(.liveActivityChanged))
      }
    }
    .cancellable(
      id: CancelID.liveActivityChanges,
      cancelInFlight: true
    )
  }

  private func syncLiveActivities(_ state: State) -> Effect<Action> {
    guard state.liveActivity.isReady, state.isForeground else { return .none }
    let now = state.liveActivity.now
    let festivals = Dictionary(
      state.festivals.map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    let updates: [Effect<Action>] = state.liveActivity.activities.values.compactMap { activity in
      guard let festival = festivals[activity.festivalID],
            let schedule = FestivalLiveActivitySchedule.resolve(
              festival: festival,
              pack: state.pack(for: festival.id),
              now: now
            ) else { return nil }
      if schedule.phase == .finished {
        return .run { send in
          await liveActivityUseCase.finish(
            activityID: activity.id,
            startDate: schedule.startDate
          )
          await send(.inner(.liveActivityStopped(
            activity.festivalID,
            activity.id
          )))
        }
        .cancellable(
          id: LiveActivitySyncID(id: activity.id),
          cancelInFlight: true
        )
      }
      let pack = state.pack(for: activity.festivalID)
      let savedSetIDs = state.mySchedule?.festivalID == activity.festivalID
        ? state.mySchedule?.setIDs ?? [] : []
      let scheduleChanged = schedule.phase != activity.phase || schedule.startDate != activity.startDate
        || schedule.endDate != activity.endDate
      guard scheduleChanged || (activity.festivalID == state.selectedFestivalID && pack != nil) else { return nil }
      return .run { send in
        await liveActivityUseCase.update(
          activityID: activity.id,
          phase: schedule.phase,
          startDate: schedule.startDate,
          endDate: schedule.endDate,
          pack: pack,
          savedSetIDs: savedSetIDs
        )
        if scheduleChanged {
          await send(.inner(.liveActivityUpdated(.init(
            id: activity.id,
            festivalID: activity.festivalID,
            phase: schedule.phase,
            startDate: schedule.startDate,
            endDate: schedule.endDate
          ))))
        }
      }
      .cancellable(
        id: LiveActivitySyncID(id: activity.id),
        cancelInFlight: true
      )
    }
    let automaticStart: Effect<Action>
    if let id = state.selectedFestivalID,
       state.hasSession,
       state.mySchedule?.festivalID == id,
       state.liveActivity.activities[id] == nil,
       state.liveActivity.busyFestivalID == nil,
       let setIDs = state.mySchedule?.setIDs,
       let start = FestivalLiveActivitySchedule.nextSavedPerformanceStart(
         pack: state.pack(for: id),
         setIDs: setIDs,
         now: now
       ),
       now >= start.addingTimeInterval(-7_200),
       state.autoActivityHandledStarts[id] != start {
      automaticStart = .send(.inner(.autoStartLiveActivity(
        festivalID: id,
        performanceStart: start
      )))
    } else {
      automaticStart = .none
    }
    return .merge(updates + [automaticStart, liveActivityBoundary(state)])
  }

  private func liveActivityBoundary(_ state: State) -> Effect<Action> {
    guard state.liveActivity.isReady, state.isForeground else {
      return .cancel(id: CancelID.liveActivityBoundary)
    }
    let relevantIDs = Set(state.liveActivity.activities.keys).union(state.selectedFestivalID.map { [$0] } ?? [])
    let festivalBoundary = state.festivals
      .filter { relevantIDs.contains($0.id) }
      .compactMap { festival in
        FestivalLiveActivitySchedule.resolve(
          festival: festival,
          pack: state.pack(for: festival.id),
          now: state.liveActivity.now
        )?.nextBoundary
      }
      .min()
    let performanceBoundary = state.selectedFestivalID.flatMap { id in
      state.mySchedule.flatMap { schedule in
        FestivalLiveActivitySchedule.nextSavedPerformanceStart(
          pack: state.pack(for: id),
          setIDs: schedule.setIDs,
          now: state.liveActivity.now
        )
      }
    }.map { start in
      let eligibility = start.addingTimeInterval(-7_200)
      return eligibility > state.liveActivity.now ? eligibility : start
    }
    let next = [festivalBoundary, performanceBoundary].compactMap { $0 }.min()
    guard let next else { return .cancel(id: CancelID.liveActivityBoundary) }
    let delay = max(
      1,
      Int64(next.timeIntervalSince(state.liveActivity.now) * 1000)
    )
    return .run { send in
      try await clock.sleep(for: .milliseconds(delay))
      await send(.inner(.liveActivityBoundary))
    }
    .cancellable(
      id: CancelID.liveActivityBoundary,
      cancelInFlight: true
    )
  }

  private func prefetchImages(_ state: State) -> Effect<Action> {
    guard state.isForeground else {
      return .run { _ in await imageUseCase.stopPrefetch() }
        .cancellable(
          id: CancelID.imagePrefetch,
          cancelInFlight: true
        )
    }
    let urls = state.prefetchImageURLs
    return .run { _ in await imageUseCase.startPrefetch(urls) }
      .cancellable(
        id: CancelID.imagePrefetch,
        cancelInFlight: true
      )
  }

  private func retryImagesAfterRecovery(in state: inout State) {
    guard state.imageRetryPending else { return }
    state.imageRetryPending = false
    state.imageRevision += 1
  }

  private func resolveImageURLs(in state: inout State) {
    var urls: [String: URL] = [:]
    for value in state.imageSourceValues {
      urls[value] = imageUseCase.imageURL(for: value)
    }
    state.imageURLs = urls
  }

  private func watchLiveBoard(_ state: State) -> Effect<Action> {
    guard state.isForeground, state.isLiveBoardVisible,
          let id = state.selectedFestivalID else {
      return .cancel(id: CancelID.liveBoard)
    }
    let generation = state.accountGeneration
    return .run { send in
      while !Task.isCancelled {
        var interval: TimeInterval = 35
        do {
          let snapshot = try await liveBoardUseCase.liveBoard(for: id)
          await send(.inner(.liveBoardLoaded(
            id,
            generation: generation,
            snapshot
          )))
        } catch FestivalLiveBoardError.festivalNotFound {
          await send(.inner(.liveBoardUnpublished(
            id,
            generation: generation
          )))
        } catch FestivalLiveBoardError.rateLimited(let retryAfter) {
          interval = max(
            interval,
            retryAfter
          )
          await send(.inner(.liveBoardFailed(
            id,
            generation: generation
          )))
        } catch {
          await send(.inner(.liveBoardFailed(
            id,
            generation: generation
          )))
        }
        try await clock.sleep(for: .seconds(interval))
      }
    }
    .cancellable(
      id: CancelID.liveBoard,
      cancelInFlight: true
    )
  }

  /// 세션이 있고 축제가 선택되어 있으면 내 일정을 불러와 자동 시작 시각을 계산한다.
  private func loadMySchedule(_ state: inout State) -> Effect<Action> {
    guard state.hasSession, state.isForeground, let id = state.selectedFestivalID else {
      return .cancel(id: CancelID.mySchedule)
    }
    state.myScheduleRequestID += 1
    state.myScheduleUnavailable = false
    let requestID = state.myScheduleRequestID
    let generation = state.accountGeneration
    return .run { send in
      do {
        let setIDs = try await scheduleUseCase.mySchedule(festivalID: id).setIDs
        await send(.inner(.myScheduleLoaded(
          festivalID: id,
          requestID: requestID,
          generation: generation,
          Set(setIDs)
        )))
      } catch {
        await send(.inner(.myScheduleFailed(
          festivalID: id,
          requestID: requestID,
          generation: generation
        )))
      }
    }
    .cancellable(
      id: CancelID.mySchedule,
      cancelInFlight: true
    )
  }

  private func watchSelectedPack(_ state: State) -> Effect<Action> {
    guard state.isForeground,
          let id = state.selectedFestivalID,
          state.cachedPacks[id] != nil else {
      return .cancel(id: CancelID.packUpdates)
    }
    return .run { send in
      do {
        for try await result in packUseCase.packUpdates(for: id) {
          await send(.inner(.packReceived(
            id,
            result
          )))
        }
      } catch {
        await send(.inner(.packFailed(id)))
      }
    }
    .cancellable(
      id: CancelID.packUpdates,
      cancelInFlight: true
    )
  }

  private func showCachedPack(in state: inout State) {
    if let id = state.selectedFestivalID, let pack = state.cachedPacks[id] {
      state.selectedPack = try? JSONDecoder().decode(
        FestivalPackDocument.self,
        from: pack.pack
      )
      state.connection = .cached
    } else {
      state.selectedPack = nil
      state.homeDetails = .idle
      state.connection = .unavailable
    }
  }

  private func loadOnlineDetailIfNeeded(_ state: inout State) -> Effect<Action> {
    guard state.isLiveBoardVisible, let id = state.selectedFestivalID,
          state.onlineDetail?.id != id, !state.onlineDetailLoading else { return .none }
    state.onlineDetailLoading = true
    state.onlineDetailFailed = false
    return .send(.async(.loadOnlineDetail(id)))
  }
}

extension FestivalFeature.State {
  /// 같은 ID가 다시 오면 처음 항목만 남긴다.
  static func uniqueCatalog(_ items: [FestivalCatalogItem]) -> IdentifiedArrayOf<FestivalCatalogItem> {
    var result: IdentifiedArrayOf<FestivalCatalogItem> = []
    for item in items where result[id: item.id] == nil {
      result.append(item)
    }
    return result
  }

  /// 현재 선택, 저장한 선택, 캐시된 축제, 팩이 있는 축제, 첫 축제 순서로 고른다.
  func initialSelectedFestivalID(savedID: String?) -> String? {
    let festivals = self.festivals
    return festivals.first { $0.id == selectedFestivalID }?.id
      ?? festivals.first { $0.id == savedID }?.id
      ?? festivals.first { $0.isCached }?.id
      ?? festivals.first { $0.packVersion > 0 }?.id
      ?? festivals.first?.id
  }

  /// 축제 썸네일과 선택 팩 이미지의 원본 값. 중복은 처음 값만 남긴다.
  var imageSourceValues: [String] {
    let festivalValues = festivals.compactMap { $0.thumbnailURL?.absoluteString }
    let packValues = displayDocument.map { pack in
      [pack.thumbUrl].compactMap { $0 }
        + (pack.artists ?? []).compactMap(\.imageUrl)
        + pack.performances.compactMap(\.imageUrl)
    } ?? []
    var seen = Set<String>()
    return (festivalValues + packValues).filter { seen.insert($0).inserted }
  }

  /// 미리 받을 이미지 URL. 선택 팩 이미지를 먼저 두고 100개까지만 받는다.
  var prefetchImageURLs: [URL] {
    let packValues = displayDocument.map { pack in
      [pack.thumbUrl].compactMap(imageURL(for:))
        + (pack.artists ?? []).compactMap { imageURL(for: $0.imageUrl) }
        + pack.performances.compactMap { imageURL(for: $0.imageUrl) }
    } ?? []
    let festivalValues = festivals.compactMap { imageURL(for: $0.thumbnailURL?.absoluteString) }
    var seen = Set<URL>()
    return Array((packValues + festivalValues).filter { seen.insert($0).inserted }.prefix(100))
  }
}
