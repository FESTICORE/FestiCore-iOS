import Dependencies
import Foundation

public struct FestivalLiveBoardSnapshot: Equatable, Sendable {
  public struct Flag: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let status: String
    public let zoneID: String?
    public let activity: String?
    public let thumbnailURL: URL?
    public let tags: [String]
    public let updatedAt: Date?
    public let followerCount: Int?
    public let homeZoneID: String?

    public init(
      id: String, name: String, status: String, zoneID: String?, activity: String?,
      thumbnailURL: URL?, tags: [String] = [], updatedAt: Date? = nil,
      followerCount: Int? = nil, homeZoneID: String? = nil
    ) {
      self.id = id
      self.name = name
      self.status = status
      self.zoneID = zoneID
      self.activity = activity
      self.thumbnailURL = thumbnailURL
      self.tags = tags
      self.updatedAt = updatedAt
      self.followerCount = followerCount
      self.homeZoneID = homeZoneID
    }
  }

  public struct Crew: Equatable, Sendable {
    public struct Member: Equatable, Identifiable, Sendable {
      public let id: String
      public let nickname: String
      public let state: String?
      public let zoneID: String?
      public let updatedAt: Date?

      public init(id: String, nickname: String, state: String?, zoneID: String?, updatedAt: Date? = nil) {
        self.id = id
        self.nickname = nickname
        self.state = state
        self.zoneID = zoneID
        self.updatedAt = updatedAt
      }
    }

    public struct GatherRequest: Equatable, Sendable {
      public let zoneID: String?
      public let byUserID: String
      public let at: Date

      public init(zoneID: String?, byUserID: String, at: Date) {
        self.zoneID = zoneID
        self.byUserID = byUserID
        self.at = at
      }
    }

    public let id: String
    public let name: String
    public let members: [Member]
    public let ownerID: String?
    public let gatherRequest: GatherRequest?
    public let gatherAvailableAt: Date?

    public init(
      id: String, name: String, members: [Member], ownerID: String? = nil,
      gatherRequest: GatherRequest? = nil, gatherAvailableAt: Date? = nil
    ) {
      self.id = id
      self.name = name
      self.members = members
      self.ownerID = ownerID
      self.gatherRequest = gatherRequest
      self.gatherAvailableAt = gatherAvailableAt
    }
  }

  public let festivalID: String
  public let activeFlags: [Flag]
  public let followedFlags: [Flag]
  public let crew: Crew?
  public let serverAt: Date?
  public let pinnedFlagID: String?
  /// 축제의 공개 깃발 전체. 공개 목록 순서에 라이브 상태를 합친다.
  public let directoryFlags: [Flag]
  /// 이 기기가 라이브 상태를 마지막으로 확인한 시각. 304로 이전 응답을 재사용해도 새로 기록한다.
  public let receivedAt: Date?

  public init(
    festivalID: String, activeFlags: [Flag], followedFlags: [Flag], crew: Crew?,
    serverAt: Date? = nil, pinnedFlagID: String? = nil, directoryFlags: [Flag] = [],
    receivedAt: Date? = nil
  ) {
    self.festivalID = festivalID
    self.activeFlags = activeFlags
    self.followedFlags = followedFlags
    self.crew = crew
    self.serverAt = serverAt
    self.pinnedFlagID = pinnedFlagID
    self.directoryFlags = directoryFlags
    self.receivedAt = receivedAt
  }
}

public protocol FestivalLiveBoardService: Sendable {
  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot
}

public enum FestivalLiveBoardError: Error, Equatable, Sendable {
  case deviceNotRegistered
  case invalidFestivalID
  case invalidResponse
  case rateLimited(retryAfter: TimeInterval)
}

public enum FestivalLiveBoardServiceDependency: TestDependencyKey {
  public static var testValue: any FestivalLiveBoardService { EmptyFestivalLiveBoardService() }
}

public extension DependencyValues {
  var festivalLiveBoardService: any FestivalLiveBoardService {
    get { self[FestivalLiveBoardServiceDependency.self] }
    set { self[FestivalLiveBoardServiceDependency.self] = newValue }
  }
}

private struct EmptyFestivalLiveBoardService: FestivalLiveBoardService {
  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    .init(festivalID: festivalID, activeFlags: [], followedFlags: [], crew: nil)
  }
}
