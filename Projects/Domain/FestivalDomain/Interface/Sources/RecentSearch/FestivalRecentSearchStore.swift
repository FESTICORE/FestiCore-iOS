import Dependencies
import Foundation

public struct FestivalRecentSearchStore: Sendable {
  public var load: @Sendable (_ userID: String?) -> [String]
  public var add: @Sendable (_ query: String, _ userID: String?) -> [String]
  public var remove: @Sendable (_ query: String, _ userID: String?) -> [String]
  public var clear: @Sendable (_ userID: String?) -> Void

  public init(
    load: @escaping @Sendable (_ userID: String?) -> [String],
    add: @escaping @Sendable (_ query: String, _ userID: String?) -> [String],
    remove: @escaping @Sendable (_ query: String, _ userID: String?) -> [String],
    clear: @escaping @Sendable (_ userID: String?) -> Void
  ) {
    self.load = load
    self.add = add
    self.remove = remove
    self.clear = clear
  }

  public func load(for userID: String?) -> [String] { load(userID) }
  public func add(_ query: String, for userID: String?) -> [String] { add(query, userID) }
  public func remove(_ query: String, for userID: String?) -> [String] { remove(query, userID) }
  public func clear(for userID: String?) { clear(userID) }
}

extension FestivalRecentSearchStore: TestDependencyKey {
  public static let testValue = Self(
    load: { _ in [] },
    add: { _, _ in [] },
    remove: { _, _ in [] },
    clear: { _ in }
  )
}

extension DependencyValues {
  public var festivalRecentSearchStore: FestivalRecentSearchStore {
    get { self[FestivalRecentSearchStore.self] }
    set { self[FestivalRecentSearchStore.self] = newValue }
  }
}
