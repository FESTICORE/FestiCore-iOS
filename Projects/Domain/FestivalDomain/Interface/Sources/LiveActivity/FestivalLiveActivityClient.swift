import Dependencies
import Foundation

public struct FestivalLiveActivityClient: Sendable {
  public var activities: @Sendable () async -> [FestivalLiveActivityRecord]
  public var changes: @Sendable () -> AsyncStream<Void>
  public var start:
    @Sendable (String, String, Date, Date, FestivalLiveActivityPhase) async throws -> String
  public var update: @Sendable (String, FestivalLiveActivityPhase, Date, Date) async -> Void
  public var finish: @Sendable (String, Date) async -> Void
  public var end: @Sendable (String) async -> Void

  public init(
    activities: @escaping @Sendable () async -> [FestivalLiveActivityRecord],
    changes: @escaping @Sendable () -> AsyncStream<Void>,
    start:
      @escaping @Sendable (String, String, Date, Date, FestivalLiveActivityPhase) async throws ->
      String,
    update: @escaping @Sendable (String, FestivalLiveActivityPhase, Date, Date) async -> Void,
    finish: @escaping @Sendable (String, Date) async -> Void,
    end: @escaping @Sendable (String) async -> Void
  ) {
    self.activities = activities
    self.changes = changes
    self.start = start
    self.update = update
    self.finish = finish
    self.end = end
  }
}

extension FestivalLiveActivityClient: TestDependencyKey {
  public static let testValue = Self(
    activities: { [] },
    changes: { AsyncStream { $0.finish() } },
    start: { _, _, _, _, _ in "test-activity" },
    update: { _, _, _, _ in },
    finish: { _, _ in },
    end: { _ in }
  )
}

extension DependencyValues {
  public var festivalLiveActivityClient: FestivalLiveActivityClient {
    get { self[FestivalLiveActivityClient.self] }
    set { self[FestivalLiveActivityClient.self] = newValue }
  }
}
