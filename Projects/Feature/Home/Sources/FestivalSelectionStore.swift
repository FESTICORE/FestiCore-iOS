import Dependencies
import Foundation

public struct FestivalSelectionStore: Sendable {
  public var load: @Sendable () -> String?
  public var save: @Sendable (String?) -> Void

  public init(
    load: @escaping @Sendable () -> String?,
    save: @escaping @Sendable (String?) -> Void
  ) {
    self.load = load
    self.save = save
  }
}

extension FestivalSelectionStore: DependencyKey {
  private static let key = "FestiCore.selectedFestivalID"

  public static let liveValue = Self(
    load: { UserDefaults.standard.string(forKey: key) },
    save: { UserDefaults.standard.set($0, forKey: key) }
  )

  public static let testValue = Self(load: { nil }, save: { _ in })
}

public extension DependencyValues {
  var festivalSelectionStore: FestivalSelectionStore {
    get { self[FestivalSelectionStore.self] }
    set { self[FestivalSelectionStore.self] = newValue }
  }
}
