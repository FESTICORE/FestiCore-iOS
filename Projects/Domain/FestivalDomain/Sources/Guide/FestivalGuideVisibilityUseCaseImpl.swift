import Dependencies
import FestivalDomainInterface

/// 깃발 안내 숨김 상태를 주입된 기기 저장소에서 조회하고 변경한다.
public struct FestivalGuideVisibilityUseCaseImpl: FestivalGuideVisibilityUseCaseInterface {
  @Dependency(\.festivalGuideVisibilityStore) private var store

  public init() {}

  public func isHidden(for festivalID: String) -> Bool { return store.isHidden(festivalID) }
  public func hide(for festivalID: String) { store.hide(festivalID) }
}
