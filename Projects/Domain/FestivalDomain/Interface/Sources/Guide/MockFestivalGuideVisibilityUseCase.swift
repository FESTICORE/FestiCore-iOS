import Dependencies

/// 테스트와 프리뷰에서 깃발 안내 숨김 동작을 주입하는 대역이다.
public struct MockFestivalGuideVisibilityUseCase: FestivalGuideVisibilityUseCaseInterface {
  private let isHiddenHandler: @Sendable (String) -> Bool
  private let hideHandler: @Sendable (String) -> Void

  public init(
    isHidden: @escaping @Sendable (String) -> Bool = { _ in
      reportIssue("festivalGuideVisibilityUseCase.isHidden 미등록")
      return false
    },
    hide: @escaping @Sendable (String) -> Void = { _ in
      reportIssue("festivalGuideVisibilityUseCase.hide 미등록")
    }
  ) {
    isHiddenHandler = isHidden
    hideHandler = hide
  }

  public func isHidden(for festivalID: String) -> Bool { return isHiddenHandler(festivalID) }
  public func hide(for festivalID: String) { hideHandler(festivalID) }
}
