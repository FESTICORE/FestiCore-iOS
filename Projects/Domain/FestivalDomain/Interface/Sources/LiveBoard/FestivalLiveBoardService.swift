import Dependencies
import Foundation

public protocol FestivalLiveBoardService: Sendable {
  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot
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
