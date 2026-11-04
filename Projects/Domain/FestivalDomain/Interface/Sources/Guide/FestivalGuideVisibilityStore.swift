import Dependencies
import Foundation

/// 축제별 라이브 보드 깃발 안내 숨김 상태를 기기에 저장한다.
public struct FestivalGuideVisibilityStore: Sendable {
  public var isHidden: @Sendable (_ festivalID: String) -> Bool
  public var hide: @Sendable (_ festivalID: String) -> Void

  public init(
    isHidden: @escaping @Sendable (_ festivalID: String) -> Bool,
    hide: @escaping @Sendable (_ festivalID: String) -> Void
  ) {
    self.isHidden = isHidden
    self.hide = hide
  }
}

extension FestivalGuideVisibilityStore: TestDependencyKey {
  public static let testValue = Self(
    isHidden: { _ in false },
    hide: { _ in reportIssue("festivalGuideVisibilityStore.hide 미등록") }
  )
}

extension DependencyValues {
  public var festivalGuideVisibilityStore: FestivalGuideVisibilityStore {
    get { self[FestivalGuideVisibilityStore.self] }
    set { self[FestivalGuideVisibilityStore.self] = newValue }
  }
}
