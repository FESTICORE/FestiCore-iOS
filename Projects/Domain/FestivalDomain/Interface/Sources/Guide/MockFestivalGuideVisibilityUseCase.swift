import Dependencies

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

  public func isHidden(for festivalID: String) -> Bool { isHiddenHandler(festivalID) }
  public func hide(for festivalID: String) { hideHandler(festivalID) }
}
