//
//  FestivalZoneMapFeature.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation

/// Figma S06 존 지도 A~J. 받아 둔 팩의 존 영역에 라이브 보드의 깃발·크루를 놓는다.
@Reducer
public struct FestivalZoneMapFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let festivalID: String
    /// 로그인한 사용자. 크루 줄에 `나`를 붙인다.
    public let viewerUserID: String?
    public var selectedZoneID: String?
    public var map: MapLoad = .loading
    public var live: Live
    /// 서버 지도 버전이 받아 둔 지도와 다르다(Figma S06 J).
    public var isMapChanged = false
    public var isUpdatingPack = false

    public init(
      festivalID: String,
      viewerUserID: String?,
      selectedZoneID: String? = nil,
      snapshot: FestivalLiveBoardSnapshot? = nil,
      receivedAt: Date? = nil
    ) {
      self.festivalID = festivalID
      self.viewerUserID = viewerUserID
      self.selectedZoneID = selectedZoneID
      live = Live(
        snapshot: snapshot,
        receivedAt: receivedAt
      )
    }
  }

  /// 받아 둔 팩의 지도 상태
  public enum MapLoad: Equatable, Sendable {
    case loading
    case loaded(FestivalZoneMap)
    /// 이 축제 팩을 받아 두지 않았다.
    case missing
    case failed
  }

  /// 라이브 보드에서 받은 깃발·크루 위치
  public struct Live: Equatable, Sendable {
    public var snapshot: FestivalLiveBoardSnapshot?
    /// 마지막으로 받은 시각. 오프라인 띠에 쓴다.
    public var receivedAt: Date?
    public var isOffline = false
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
    case onAppear
    case backTapped
    case zoneTapped(String)
    case mapBackgroundTapped
    case updatePackTapped
    case followGuideTapped
    case retryTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case loadMap
    case watchLive
    case checkMapVersion(FestivalZoneMap)
    case updatePack
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case mapLoaded(FestivalZoneMap?)
    case mapFailed
    case liveLoaded(FestivalLiveBoardSnapshot)
    case liveFailed
    case mapVersionChecked(Bool)
    case packUpdated
    case packUpdateFailed
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum DelegateAction: Equatable {
    case backRequested
    case flagDirectoryRequested
  }

  enum CancelID {
    case map
    case live
    case version
    case update
  }

  @Dependency(\.festivalZoneMapUseCase) private var zoneMapUseCase
  @Dependency(\.festivalLiveBoardUseCase) private var liveBoardUseCase
  @Dependency(\.festivalPackDetailUseCase) private var packDetailUseCase
  @Dependency(\.date) private var date
  @Dependency(\.continuousClock) private var clock

  /// 라이브 보드(`FestivalFeature`)와 같은 위치 갱신 주기(초)
  static let liveRefreshInterval: TimeInterval = 35

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case .async(let asyncAction):
        return handleAsyncAction(
          state: &state,
          action: asyncAction
        )

      case .inner(let innerAction):
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

extension FestivalZoneMapFeature.State {
  public var loadedMap: FestivalZoneMap? {
    guard case let .loaded(map) = map else { return nil }
    return map
  }
}

extension FestivalZoneMapFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      return .merge(
        .send(.async(.loadMap)),
        .send(.async(.watchLive))
      )

    case .backTapped:
      return .send(.delegate(.backRequested))

    case let .zoneTapped(zoneID):
      state.selectedZoneID = state.selectedZoneID == zoneID ? nil : zoneID
      return .none

    case .mapBackgroundTapped:
      state.selectedZoneID = nil
      return .none

    case .updatePackTapped:
      guard !state.isUpdatingPack else { return .none }
      state.isUpdatingPack = true
      return .send(.async(.updatePack))

    case .followGuideTapped:
      return .send(.delegate(.flagDirectoryRequested))

    case .retryTapped:
      state.map = .loading
      return .send(.async(.loadMap))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .loadMap:
      let festivalID = state.festivalID
      let now = date.now
      return .run { send in
        do {
          let map = try await zoneMapUseCase.cachedMap(
            festivalID: festivalID,
            now: now
          )
          await send(.inner(.mapLoaded(map)))
        } catch {
          await send(.inner(.mapFailed))
        }
      }
      .cancellable(
        id: CancelID.map,
        cancelInFlight: true
      )

    case .watchLive:
      let festivalID = state.festivalID
      // 라이브 보드와 같은 주기로 깃발·크루 위치를 다시 받는다. 서버가 늦추라고 하면 그만큼 기다린다.
      return .run { send in
        while !Task.isCancelled {
          var interval = Self.liveRefreshInterval
          do {
            let snapshot = try await liveBoardUseCase.liveBoard(for: festivalID)
            await send(.inner(.liveLoaded(snapshot)))
          } catch FestivalLiveBoardError.rateLimited(let retryAfter) {
            interval = max(
              interval,
              retryAfter
            )
            await send(.inner(.liveFailed))
          } catch {
            await send(.inner(.liveFailed))
          }
          try await clock.sleep(for: .seconds(interval))
        }
      }
      .cancellable(
        id: CancelID.live,
        cancelInFlight: true
      )

    case let .checkMapVersion(map):
      return .run { send in
        let changed = (try? await zoneMapUseCase.isMapChanged(map)) ?? false
        await send(.inner(.mapVersionChecked(changed)))
      }
      .cancellable(
        id: CancelID.version,
        cancelInFlight: true
      )

    case .updatePack:
      let festivalID = state.festivalID
      return .run { send in
        do {
          _ = try await packDetailUseCase.updatePack(festivalID: festivalID)
          await send(.inner(.packUpdated))
        } catch {
          await send(.inner(.packUpdateFailed))
        }
      }
      .cancellable(
        id: CancelID.update,
        cancelInFlight: true
      )
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .mapLoaded(map):
      guard let map else {
        state.map = .missing
        return .none
      }
      state.map = .loaded(map)
      if let selected = state.selectedZoneID, map.zone(id: selected) == nil {
        state.selectedZoneID = nil
      }
      return .send(.async(.checkMapVersion(map)))

    case .mapFailed:
      state.map = .failed
      return .none

    case let .liveLoaded(snapshot):
      state.live.snapshot = snapshot
      state.live.receivedAt = snapshot.receivedAt ?? date.now
      state.live.isOffline = false
      return .none

    case .liveFailed:
      state.live.isOffline = true
      return .none

    case let .mapVersionChecked(changed):
      state.isMapChanged = changed
      return .none

    case .packUpdated:
      state.isUpdatingPack = false
      state.isMapChanged = false
      return .send(.async(.loadMap))

    case .packUpdateFailed:
      state.isUpdatingPack = false
      return .none
    }
  }
}
