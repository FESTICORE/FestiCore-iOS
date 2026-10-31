//
//  FestivalFlagDirectory.swift
//  Festival
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation

/// S04 깃발 디렉토리의 필터·정렬·팔로우 상태.
@Reducer
public struct FestivalFlagDirectory {
  @Dependency(\.festivalFlagFollowService) private var followService
  @Dependency(\.continuousClock) private var clock

  public init() {}

  public enum Tag: String, CaseIterable, Equatable, Sendable {
    case slam, sing, train, calm, newbie

    public var title: String {
      switch self {
      case .slam: "슬램"
      case .sing: "떼창"
      case .train: "기차놀이"
      case .calm: "차분"
      case .newbie: "초보 환영"
      }
    }
  }

  /// "새로 생긴 순"은 서버에 생성 시각이 없어 두지 않는다.
  public enum Sort: CaseIterable, Equatable, Sendable {
    case active, followers, recent

    public var title: String {
      switch self {
      case .active: "활동 중 순"
      case .followers: "팔로워 많은 순"
      case .recent: "최근 업데이트 순"
      }
    }
  }

  public enum Status: Equatable, Sendable {
    case active, resting, scheduled, endedToday
  }

  /// 팔로우 성공 응답. 팔로우 여부와 팔로워 수는 따로 서버 값으로 돌아간다.
  struct FollowOverride: Equatable {
    var isFollowing: Bool?
    var followerCount: Int?
    /// 팔로우를 누를 때 스냅샷의 팔로워 수. 같은 값이 다시 오면 공개 캐시가 아직 바뀌지 않은 것이다.
    let baseCount: Int?
    /// 성공 시점에 진행 중이던 조회는 팔로우 전 상태일 수 있어 한 번 건너뛴다.
    var skipsNextLoad = false
  }

  @ObservableState
  public struct State: Equatable {
    public var tag: Tag?
    public var sort: Sort = .active
    public var isSortMenuPresented = false
    public var zoneNames: [String: String] = [:]
    public var toast: String?
    var pendingFollows: [String: Int?] = [:]
    var followOverrides: [String: FollowOverride] = [:]

    public init() {}

    public func isPending(_ id: String) -> Bool {
      pendingFollows[id] != nil
    }
  }

  public enum Action: Equatable {
    case tagSelected(Tag?)
    case sortTapped
    case sortSelected(Sort)
    case sortMenuDismissed
    case followTapped(id: String, follow: Bool, baseCount: Int?)
    case followResponse(id: String, Result<FestivalFlagFollowResult, FestivalFlagFollowError>)
    case toastExpired
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable {
      case loginRequested
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .tagSelected(tag):
        state.tag = tag
        state.isSortMenuPresented = false
        return .none

      case .sortTapped:
        state.isSortMenuPresented.toggle()
        return .none

      case let .sortSelected(sort):
        state.sort = sort
        state.isSortMenuPresented = false
        return .none

      case .sortMenuDismissed:
        state.isSortMenuPresented = false
        return .none

      case let .followTapped(id, follow, baseCount):
        guard !state.isPending(id) else { return .none }
        state.pendingFollows[id] = .some(baseCount)
        return .run { [followService] send in
          do {
            let result = try await followService.setFollowing(follow, flagID: id)
            await send(.followResponse(id: id, .success(result)))
          } catch let error as FestivalFlagFollowError {
            await send(.followResponse(id: id, .failure(error)))
          } catch {
            await send(.followResponse(id: id, .failure(.unavailable)))
          }
        }
        .cancellable(id: FlagDirectoryCancelID.follow(id))

      case let .followResponse(id, result):
        // 탭 이탈·축제·계정 변경으로 비운 요청의 늦은 응답은 버린다.
        guard let baseCount = state.pendingFollows.removeValue(forKey: id) else { return .none }
        switch result {
        case let .success(response):
          state.followOverrides[id] = FollowOverride(
            isFollowing: response.isFollowing,
            followerCount: response.followerCount,
            baseCount: baseCount
          )
          return .none
        case .failure(.loginRequired):
          return .send(.delegate(.loginRequested))
        case .failure(.limitReached):
          return showToast("팔로우는 100개까지 할 수 있어요", state: &state)
        case .failure:
          return showToast("팔로우를 바꾸지 못했어요. 잠시 후 다시 시도해 주세요", state: &state)
        }

      case .toastExpired:
        state.toast = nil
        return .none

      case .delegate:
        return .none
      }
    }
  }

  private func showToast(_ message: String, state: inout State) -> Effect<Action> {
    state.toast = message
    return .run { send in
      try await clock.sleep(for: .seconds(2))
      await send(.toastExpired)
    }
    .cancellable(id: FlagDirectoryCancelID.toast, cancelInFlight: true)
  }
}

enum FlagDirectoryCancelID: Hashable {
  case follow(String)
  case toast
}

// MARK: - 표시 행

public extension FestivalFlagDirectory {
  struct Row: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let thumbnailURL: URL?
    /// nil이면 상태를 알 수 없다(라이브 목록 상한).
    public let status: Status?
    public let followersText: String
    public let tags: [String]
    public let zone: String
    public let isFollowing: Bool
    /// 팔로우를 누를 때 넘길 스냅샷의 팔로워 수
    public let serverFollowerCount: Int?
    public let isFollowEnabled: Bool
  }

  /// 마지막 확인 시각으로 오프라인 배지 문구를 만든다.
  static func offlineText(receivedAt: Date?, now: Date) -> String {
    guard let receivedAt else { return "오프라인 · 방금 전 정보" }
    let minutes = Int(now.timeIntervalSince(receivedAt) / 60)
    return minutes >= 1 ? "오프라인 · \(minutes)분 전 정보" : "오프라인 · 방금 전 정보"
  }
}

public extension FestivalFlagDirectory.State {
  /// 필터·정렬을 적용한 카드 목록. 성공한 팔로우 값은 서버 확인 전까지 스냅샷보다 우선한다.
  /// `isFailed`면 이전 목록을 보이는 중이므로 팔로우를 막는다.
  func rows(in snapshot: FestivalLiveBoardSnapshot, isFailed: Bool) -> [FestivalFlagDirectory.Row] {
    let followedIDs = Set(snapshot.followedFlags.map(\.id))
    let rows = snapshot.directoryFlags.enumerated().compactMap { index, flag -> (Int, FestivalLiveBoardSnapshot.Flag, FestivalFlagDirectory.Row)? in
      if let tag, !flag.tags.contains(tag.rawValue) {
        return nil
      }
      let override = followOverrides[flag.id]
      let count = override?.followerCount ?? flag.followerCount ?? 0
      let zoneID = flag.zoneID ?? flag.homeZoneID
      let row = FestivalFlagDirectory.Row(
        id: flag.id,
        name: flag.name,
        thumbnailURL: flag.thumbnailURL,
        status: Self.status(flag.status),
        followersText: "팔로워 \(count.formatted(.number.locale(Locale(identifier: "ko_KR"))))",
        tags: flag.tags.compactMap { FestivalFlagDirectory.Tag(rawValue: $0)?.title },
        zone: zoneID.flatMap { zoneNames[$0] } ?? "위치 미정",
        isFollowing: override?.isFollowing ?? followedIDs.contains(flag.id),
        serverFollowerCount: flag.followerCount,
        isFollowEnabled: !isFailed && !isPending(flag.id)
      )
      return (index, flag, row)
    }
    return rows.sorted { lhs, rhs in
      switch sort {
      case .active:
        let (left, right) = (Self.rank(lhs.2.status), Self.rank(rhs.2.status))
        if left != right {
          return left < right
        }
        let (leftCount, rightCount) = (displayCount(lhs.1), displayCount(rhs.1))
        if leftCount != rightCount {
          return leftCount > rightCount
        }
      case .followers:
        let (leftCount, rightCount) = (displayCount(lhs.1), displayCount(rhs.1))
        if leftCount != rightCount {
          return leftCount > rightCount
        }
      case .recent:
        switch (lhs.1.updatedAt, rhs.1.updatedAt) {
        case let (left?, right?) where left != right: return left > right
        case (.some, nil): return true
        case (nil, .some): return false
        default: break
        }
      }
      return lhs.0 < rhs.0
    }
    .map(\.2)
  }
}

extension FestivalFlagDirectory.State {
  /// 부모가 받아들인 새 스냅샷으로 덮어쓰기 값을 서버 값에 넘긴다.
  mutating func reconcile(with snapshot: FestivalLiveBoardSnapshot) {
    let followedIDs = Set(snapshot.followedFlags.map(\.id))
    let serverCounts = Dictionary(
      snapshot.directoryFlags.map { ($0.id, $0.followerCount) }, uniquingKeysWith: { first, _ in first }
    )
    for (id, var override) in followOverrides {
      if override.skipsNextLoad {
        override.skipsNextLoad = false
      } else {
        // 304 재사용 응답은 팔로우 전 상태일 수 있으므로 일치할 때만 서버 값에 넘긴다.
        if override.isFollowing == followedIDs.contains(id) {
          override.isFollowing = nil
        }
        // 공개 목록은 최대 10분 캐시된다. 팔로우 전과 같은 수면 아직 바뀌지 않은 응답이다.
        if serverCounts[id].flatMap({ $0 }) != override.baseCount {
          override.followerCount = nil
        }
      }
      followOverrides[id] = override.isFollowing == nil && override.followerCount == nil ? nil : override
    }
  }

  /// 새 조회가 이전 조회를 취소하면 건너뛸 이유가 사라진다.
  mutating func clearLoadSkips() {
    for id in followOverrides.keys where followOverrides[id]?.skipsNextLoad == true {
      followOverrides[id]?.skipsNextLoad = false
    }
  }

  /// 탭을 떠나면 진행 중인 요청과 표시만 비우고 성공값은 다음 확인까지 남긴다.
  mutating func leaveTab() -> [String] {
    let ids = Array(pendingFollows.keys)
    if !pendingFollows.isEmpty {
      pendingFollows = [:]
    }
    if toast != nil {
      toast = nil
    }
    if isSortMenuPresented {
      isSortMenuPresented = false
    }
    for id in followOverrides.keys where followOverrides[id]?.skipsNextLoad == true {
      followOverrides[id]?.skipsNextLoad = false
    }
    return ids
  }

  /// 축제·계정이 바뀌면 이전 문맥의 팔로우 값을 모두 버린다.
  mutating func resetContext() -> [String] {
    let ids = leaveTab()
    if !followOverrides.isEmpty {
      followOverrides = [:]
    }
    return ids
  }

  fileprivate func displayCount(_ flag: FestivalLiveBoardSnapshot.Flag) -> Int {
    followOverrides[flag.id]?.followerCount ?? flag.followerCount ?? 0
  }

  fileprivate static func status(_ value: String) -> FestivalFlagDirectory.Status? {
    switch value {
    case "active": .active
    case "resting": .resting
    case "scheduled": .scheduled
    case "ended": .endedToday
    default: nil
    }
  }

  fileprivate static func rank(_ status: FestivalFlagDirectory.Status?) -> Int {
    switch status {
    case .active: 0
    case .resting: 1
    case nil: 2
    case .scheduled: 3
    case .endedToday: 4
    }
  }
}

// MARK: - 부모 동기화

extension Reducer where State == FestivalFlagFeature.State, Action == FestivalFlagFeature.Action {
  /// 깃발 목록 리듀서가 처리한 결과에 맞춰 디렉토리 상태를 정리한다.
  /// 부모 액션의 연관값은 읽지 않는다.
  func syncFlagDirectory() -> some ReducerOf<FestivalFlagFeature> {
    FlagDirectorySync(base: self)
  }
}

private struct FlagDirectorySync<Base: Reducer>: Reducer
  where Base.State == FestivalFlagFeature.State, Base.Action == FestivalFlagFeature.Action
{
  let base: Base

  func reduce(into state: inout FestivalFlagFeature.State, action: FestivalFlagFeature.Action) -> Effect<FestivalFlagFeature.Action> {
    let wasLoading = state.viewState == .loading
    let effect = base.reduce(into: &state, action: action)
    switch action {
    case .appeared, .refresh:
      state.directory.clearLoadSkips()
    case .loaded:
      // 거부된 응답은 viewState를 바꾸지 않는다.
      if wasLoading, state.viewState == .loaded, let snapshot = state.snapshot {
        state.directory.reconcile(with: snapshot)
      }
    case let .directory(.followResponse(id, .success)):
      if state.viewState == .loading {
        state.directory.followOverrides[id]?.skipsNextLoad = true
      }
    case .disappeared:
      return .merge(effect, cancel(state.directory.leaveTab()))
    case .festivalChanged, .accountChanged:
      return .merge(effect, cancel(state.directory.resetContext()))
    default:
      break
    }
    return effect
  }

  private func cancel(_ ids: [String]) -> Effect<FestivalFlagFeature.Action> {
    .merge(ids.map { .cancel(id: FlagDirectoryCancelID.follow($0)) } + [.cancel(id: FlagDirectoryCancelID.toast)])
  }
}
