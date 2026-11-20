import ComposableArchitecture
import FestivalDomainInterface
import Foundation

/// 라이브 보드의 조회 효과와 응답·수신·오류 표시 상태를 맡는 자식 리듀서.
/// 시작 조건(포그라운드·화면 표시·축제 선택)은 부모 `FestivalFeature`가 판단해 시작·새로고침·중지 입력으로 보낸다.
@Reducer
public struct FestivalLiveBoardFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var snapshot: FestivalLiveBoardSnapshot?
    public var isUnavailable = false
    public var isUnpublished = false
    /// 현재 serverAt을 처음 받은 기기 시각. 304 응답에서도 서버 시각 보정 기준을 유지한다.
    public var clockAnchorAt: Date?
    /// 마지막으로 라이브 보드가 정상 확인된 기기 시각. 304 응답도 포함한다.
    public var receivedAt: Date?
    /// 부모가 자식 상태를 읽을 때마다 채우는 현재 선택 축제와 계정 세대.
    /// 응답이 지금 축제·계정의 것인지 확인하는 데만 쓰고, 부모 저장 상태에는 남기지 않는다.
    public var selectedFestivalID: String?
    public var accountGeneration = 0
    /// 축제 공식 인스타그램 최근 게시물과 그 축제 ID. 다른 축제로 바꾸면 새 소식을 받기 전까지 숨긴다.
    public var officialNews: FestivalOfficialNews?
    public var officialNewsFestivalID: String?

    public init() {}

    /// 지금 선택한 축제의 공식 소식. 받기 전이거나 다른 축제 것이면 nil이다.
    public var visibleOfficialNews: FestivalOfficialNews? {
      guard let officialNews, officialNewsFestivalID == selectedFestivalID else { return nil }
      return officialNews
    }
  }

  public enum Action: ViewAction, Equatable {
    case view(View)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  /// 부모가 시작 조건을 확인한 뒤 보내는 입력.
  @CasePathable
  public enum View: Equatable {
    case watchRequested(
      festivalID: String,
      generation: Int
    )
    case refreshRequested(
      festivalID: String,
      generation: Int
    )
    case stopped
    case retried
    case cleared
    /// 라이브 보드 화면의 `다시 시도` 탭. 재조회 조건은 부모가 판단한다.
    case retryTapped
    /// 팔로우한 깃발 섹션의 로그인 탭. 처리는 부모가 한다.
    case followLoginTapped
    /// 팔로우 안내의 `깃발 찾기` 탭. 처리는 부모가 한다.
    case findFlagTapped
    /// 팔로우 안내의 닫기 탭. 숨김 확인은 부모가 띄운다.
    case hideFollowGuideTapped
    /// 크루 섹션의 로그인 탭. 처리는 부모가 한다.
    case crewLoginTapped
    /// 크루 카드의 `모여!` 탭. 처리는 부모가 한다.
    case gatherCrewTapped
    /// 크루 카드의 구역 칩 탭. 처리는 부모가 한다.
    case crewZoneTapped(String)
    /// 빈 크루의 `크루 만들기` 탭. 처리는 부모가 한다.
    case createCrewTapped
    /// 크루 카드 열기 탭. 처리는 부모가 한다.
    case crewTapped
    /// 공식 인스타그램 게시물 탭. 원본 게시물을 연다.
    case officialNewsPostTapped(URL)
  }

  // MARK: - InnerAction

  @CasePathable
  public enum InnerAction: Equatable {
    case liveBoardLoaded(String, generation: Int, FestivalLiveBoardSnapshot)
    case liveBoardFailed(String, generation: Int)
    case liveBoardUnpublished(String, generation: Int)
    case officialNewsLoaded(String, generation: Int, FestivalOfficialNews)
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum DelegateAction: Equatable {
    case retryRequested
    case followLoginRequested
    case findFlagRequested
    case hideFollowGuideRequested
    case crewLoginRequested
    case gatherCrewRequested
    case crewZoneRequested(String)
    case createCrewRequested
    case crewOpenRequested
  }

  enum CancelID {
    case liveBoard
    case officialNews
  }

  /// 서버가 공식 인스타그램을 5분마다 받으므로 앱도 같은 간격으로 다시 읽는다.
  static let officialNewsInterval: Duration = .seconds(300)

  @Dependency(\.festivalLiveBoardUseCase) private var liveBoardUseCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock
  @Dependency(\.openURL) private var openURL

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

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

// MARK: - 액션 처리

extension FestivalLiveBoardFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .watchRequested(
      festivalID,
      generation
    ):
      return .merge(
        watchLiveBoard(
          festivalID: festivalID,
          generation: generation
        ),
        watchOfficialNews(
          festivalID: festivalID,
          generation: generation
        )
      )

    case let .refreshRequested(
      festivalID,
      generation
    ):
      return refreshLiveBoard(
        festivalID: festivalID,
        generation: generation
      )

    case .stopped:
      return .merge(
        .cancel(id: CancelID.liveBoard),
        .cancel(id: CancelID.officialNews)
      )

    case .retried:
      state.isUnavailable = false
      return .none

    case .cleared:
      state = State()
      return .none

    case .retryTapped:
      return .send(.delegate(.retryRequested))

    case .followLoginTapped:
      return .send(.delegate(.followLoginRequested))

    case .findFlagTapped:
      return .send(.delegate(.findFlagRequested))

    case .hideFollowGuideTapped:
      return .send(.delegate(.hideFollowGuideRequested))

    case .crewLoginTapped:
      return .send(.delegate(.crewLoginRequested))

    case .gatherCrewTapped:
      return .send(.delegate(.gatherCrewRequested))

    case let .crewZoneTapped(zoneID):
      return .send(.delegate(.crewZoneRequested(zoneID)))

    case .createCrewTapped:
      return .send(.delegate(.createCrewRequested))

    case .crewTapped:
      return .send(.delegate(.crewOpenRequested))

    case let .officialNewsPostTapped(url):
      return .run { _ in
        await openURL(url)
      }
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .liveBoardLoaded(
      id,
      generation,
      snapshot
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      if state.snapshot?.serverAt != snapshot.serverAt || state.clockAnchorAt == nil {
        state.clockAnchorAt = date.now
      }
      state.snapshot = snapshot
      state.isUnavailable = false
      state.isUnpublished = false
      state.receivedAt = date.now
      return .none

    case let .liveBoardUnpublished(
      id,
      generation
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      state.snapshot = nil
      state.isUnavailable = false
      state.isUnpublished = true
      state.clockAnchorAt = nil
      state.receivedAt = nil
      return .none

    case let .liveBoardFailed(
      id,
      generation
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      state.isUnavailable = true
      return .none

    case let .officialNewsLoaded(
      id,
      generation,
      news
    ):
      guard state.selectedFestivalID == id, state.accountGeneration == generation else { return .none }
      state.officialNews = news
      state.officialNewsFestivalID = id
      return .none
    }
  }

  private func watchLiveBoard(
    festivalID id: String,
    generation: Int
  ) -> Effect<Action> {
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
          // 조회 제한은 장애가 아니다. 보이던 보드를 그대로 두고 허용 시각 뒤에 다시 불러온다.
          interval = max(
            interval,
            retryAfter
          )
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

  /// 공식 인스타그램 최근 게시물을 5분마다 다시 읽는다. 보조 정보라 실패하면 보이던 소식을 그대로 두고,
  /// 결과가 바뀌었을 때만 상태에 반영한다. 처음에는 비어 있는 소식으로 보고 같으면 보내지 않는다.
  private func watchOfficialNews(
    festivalID id: String,
    generation: Int
  ) -> Effect<Action> {
    return .run { send in
      var lastSent = FestivalOfficialNews.unavailable
      while !Task.isCancelled {
        if let news = try? await liveBoardUseCase.officialNews(for: id), news != lastSent {
          lastSent = news
          await send(.inner(.officialNewsLoaded(
            id,
            generation: generation,
            news
          )))
        }
        try await clock.sleep(for: Self.officialNewsInterval)
      }
    }
    .cancellable(
      id: CancelID.officialNews,
      cancelInFlight: true
    )
  }

  private func refreshLiveBoard(
    festivalID id: String,
    generation: Int
  ) -> Effect<Action> {
    return .run { send in
      do {
        await send(.inner(.liveBoardLoaded(
          id,
          generation: generation,
          try await liveBoardUseCase.liveBoard(for: id)
        )))
      } catch FestivalLiveBoardError.festivalNotFound {
        await send(.inner(.liveBoardUnpublished(
          id,
          generation: generation
        )))
      } catch {
        await send(.inner(.liveBoardFailed(
          id,
          generation: generation
        )))
      }
    }
  }
}
