import Dependencies
import Foundation

/// 축제 화면의 스냅샷을 Widget이 읽는 공유 저장소에 반영한다.
public struct FestivalWidgetClient: Sendable {
  public var save: @Sendable (FestivalWidgetSnapshot?) async -> Void

  public init(save: @escaping @Sendable (FestivalWidgetSnapshot?) async -> Void) {
    self.save = save
  }
}

extension FestivalWidgetClient: TestDependencyKey {
  public static let testValue = Self(save: { _ in })
}

public extension DependencyValues {
  var festivalWidgetClient: FestivalWidgetClient {
    get { self[FestivalWidgetClient.self] }
    set { self[FestivalWidgetClient.self] = newValue }
  }
}
