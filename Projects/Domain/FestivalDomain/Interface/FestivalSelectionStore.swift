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

extension FestivalSelectionStore: TestDependencyKey {
  public static let testValue = Self(load: { nil }, save: { _ in })
}

extension DependencyValues {
  public var festivalSelectionStore: FestivalSelectionStore {
    get { self[FestivalSelectionStore.self] }
    set { self[FestivalSelectionStore.self] = newValue }
  }
}
