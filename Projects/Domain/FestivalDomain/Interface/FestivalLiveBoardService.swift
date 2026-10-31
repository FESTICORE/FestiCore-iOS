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
    public let updatedAt: Date?

    public init(id: String, name: String, status: String, zoneID: String?, activity: String?, thumbnailURL: URL?, updatedAt: Date? = nil) {
      self.id = id
      self.name = name
      self.status = status
      self.zoneID = zoneID
      self.activity = activity
      self.thumbnailURL = thumbnailURL
      self.updatedAt = updatedAt
    }
  }

  public struct Crew: Equatable, Sendable {
    public struct Member: Equatable, Identifiable, Sendable {
      public let id: String
      public let nickname: String
      public let state: String
      public let zoneID: String?

      public init(id: String, nickname: String, state: String, zoneID: String?) {
        self.id = id
        self.nickname = nickname
        self.state = state
        self.zoneID = zoneID
      }
    }

    public let id: String
    public let name: String
    public let members: [Member]

    public init(id: String, name: String, members: [Member]) {
      self.id = id
      self.name = name
      self.members = members
    }
  }

  public let festivalID: String
  public let activeFlags: [Flag]
  public let followedFlags: [Flag]
  public let crew: Crew?
  public let serverAt: Date?

  public init(festivalID: String, activeFlags: [Flag], followedFlags: [Flag], crew: Crew?, serverAt: Date? = nil) {
    self.festivalID = festivalID
    self.activeFlags = activeFlags
    self.followedFlags = followedFlags
    self.crew = crew
    self.serverAt = serverAt
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
