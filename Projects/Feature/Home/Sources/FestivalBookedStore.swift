import Dependencies
import Foundation

public struct FestivalBookedStore: Sendable {
  public var load: @Sendable () -> Set<String>
  public var save: @Sendable (Set<String>) -> Void

  public init(
    load: @escaping @Sendable () -> Set<String>,
    save: @escaping @Sendable (Set<String>) -> Void
  ) {
    self.load = load
    self.save = save
  }
}

extension FestivalBookedStore: DependencyKey {
  private static let key = "FestiCore.bookedFestivalIDs"

  public static let liveValue = Self(
    load: { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) },
    save: { UserDefaults.standard.set($0.sorted(), forKey: key) }
  )

  public static let testValue = Self(load: { [] }, save: { _ in })
}

public extension DependencyValues {
  var festivalBookedStore: FestivalBookedStore {
    get { self[FestivalBookedStore.self] }
    set { self[FestivalBookedStore.self] = newValue }
  }
}
