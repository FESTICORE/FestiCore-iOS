//
//  FestivalPrepFlagsFeature.swift
//  Festival
//
//  Created by FestiCore on 11/9/26.
//

import ComposableArchitecture
import FestivalDomainInterface

/// Figma S15-② 준비 안내 · 깃발 팔로우. 깃발 탭과 같은 목록·팔로우를 쓰고 단계 이동만 더한다.
@Reducer
public struct FestivalPrepFlagsFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var flag: FestivalFlagFeature.State

    /// - Parameter zoneNames: 팩의 존 이름. 카드의 위치 글자에 쓴다.
    public init(
      festivalID: String,
      zoneNames: [String: String] = [:]
    ) {
      flag = FestivalFlagFeature.State(festivalID: festivalID)
      flag.tracksScreenView = false
      flag.directory.zoneNames = zoneNames
    }

    /// 성향 칩과 관계없이 지금 팔로우 중인 깃발 수
    public var followingCount: Int {
      guard let snapshot = flag.snapshot else { return 0 }
      var all = flag.directory
      all.tag = nil
      return all.rows(
        in: snapshot,
        isFailed: false
      ).filter(\.isFollowing).count
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case flag(FestivalFlagFeature.Action)
    case delegate(Delegate)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case onDisappear
    case tagSelected(FestivalFlagDirectory.Tag?)
    case followTapped(
      id: String,
      follow: Bool,
      baseCount: Int?
    )
    case nextTapped
    case skipTapped
    case laterTapped
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum Delegate: Equatable {
    /// 다음 단계(준비물)로 간다. 팔로우는 누를 때마다 이미 저장했다.
    case finished
    /// 준비 안내 전체를 나중에 한다.
    case later
    case loginRequested
    case termsAcceptanceRequested
  }

  public var body: some ReducerOf<Self> {
    Scope(
      state: \.flag,
      action: \.flag
    ) {
      FestivalFlagFeature()
    }
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(action: viewAction)

      case .flag(.directory(.delegate(.loginRequested))):
        return .send(.delegate(.loginRequested))

      case .flag(.directory(.delegate(.termsAcceptanceRequested))):
        return .send(.delegate(.termsAcceptanceRequested))

      case .flag, .delegate:
        return .none
      }
    }
  }
}

extension FestivalPrepFlagsFeature {
  private func handleViewAction(action: View) -> Effect<Action> {
    switch action {
    case .onAppear:
      return .send(.flag(.view(.appeared)))

    case .onDisappear:
      return .send(.flag(.view(.disappeared)))

    case .tagSelected(let tag):
      return .send(.flag(.directory(.view(.tagSelected(tag)))))

    case let .followTapped(
      id,
      follow,
      baseCount
    ):
      return .send(.flag(.directory(.view(.followTapped(
        id: id,
        follow: follow,
        baseCount: baseCount
      )))))

    case .nextTapped, .skipTapped:
      return .send(.delegate(.finished))

    case .laterTapped:
      return .send(.delegate(.later))
    }
  }
}
