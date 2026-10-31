import Dependencies
import Foundation

public struct FestivalImagePrefetchClient: Sendable {
  public var start: @Sendable ([URL]) async -> Void
  public var stop: @Sendable () async -> Void

  public init(
    start: @escaping @Sendable ([URL]) async -> Void,
    stop: @escaping @Sendable () async -> Void
  ) {
    self.start = start
    self.stop = stop
  }
}

extension FestivalImagePrefetchClient: TestDependencyKey {
  public static let testValue = Self(start: { _ in }, stop: {})
}

extension DependencyValues {
  public var festivalImagePrefetchClient: FestivalImagePrefetchClient {
    get { self[FestivalImagePrefetchClient.self] }
    set { self[FestivalImagePrefetchClient.self] = newValue }
  }
}
