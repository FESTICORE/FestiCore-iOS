import Dependencies

/// 축제별 깃발 안내의 숨김 여부 조회와 변경을 정의한다.
public protocol FestivalGuideVisibilityUseCaseInterface: Sendable {
  func isHidden(for festivalID: String) -> Bool
  func hide(for festivalID: String)
}

public enum FestivalGuideVisibilityUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalGuideVisibilityUseCaseInterface {
    return MockFestivalGuideVisibilityUseCase()
  }

  public static var previewValue: any FestivalGuideVisibilityUseCaseInterface {
    return MockFestivalGuideVisibilityUseCase(
      isHidden: { _ in false },
      hide: { _ in }
    )
  }
}

public extension DependencyValues {
  var festivalGuideVisibilityUseCase: any FestivalGuideVisibilityUseCaseInterface {
    get { self[FestivalGuideVisibilityUseCaseDependency.self] }
    set { self[FestivalGuideVisibilityUseCaseDependency.self] = newValue }
  }
}
