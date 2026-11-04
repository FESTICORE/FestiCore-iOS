import Dependencies

public protocol FestivalGuideVisibilityUseCaseInterface: Sendable {
  func isHidden(for festivalID: String) -> Bool
  func hide(for festivalID: String)
}

public enum FestivalGuideVisibilityUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalGuideVisibilityUseCaseInterface {
    MockFestivalGuideVisibilityUseCase()
  }

  public static var previewValue: any FestivalGuideVisibilityUseCaseInterface {
    MockFestivalGuideVisibilityUseCase(isHidden: { _ in false }, hide: { _ in })
  }
}

public extension DependencyValues {
  var festivalGuideVisibilityUseCase: any FestivalGuideVisibilityUseCaseInterface {
    get { self[FestivalGuideVisibilityUseCaseDependency.self] }
    set { self[FestivalGuideVisibilityUseCaseDependency.self] = newValue }
  }
}
