import Dependencies
import FestivalDomainInterface

public struct FestivalGuideVisibilityUseCaseImpl: FestivalGuideVisibilityUseCaseInterface {
  @Dependency(\.festivalGuideVisibilityStore) private var store

  public init() {}

  public func isHidden(for festivalID: String) -> Bool { store.isHidden(festivalID) }
  public func hide(for festivalID: String) { store.hide(festivalID) }
}
