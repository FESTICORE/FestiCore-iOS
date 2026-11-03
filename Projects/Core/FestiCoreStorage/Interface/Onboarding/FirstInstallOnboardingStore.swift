import Dependencies
import Foundation

/// 현재 앱 설치에서 첫 실행 온보딩을 마쳤는지 기록한다.
public struct FirstInstallOnboardingStore: Sendable {
  public var hasCompleted: @Sendable () throws -> Bool
  public var markCompleted: @Sendable () throws -> Void

  public init(
    hasCompleted: @escaping @Sendable () throws -> Bool,
    markCompleted: @escaping @Sendable () throws -> Void
  ) {
    self.hasCompleted = hasCompleted
    self.markCompleted = markCompleted
  }
}

public enum FirstInstallOnboardingStoreDependency: TestDependencyKey {
  public static let testValue = FirstInstallOnboardingStore(
    hasCompleted: { throw UnimplementedFirstInstallOnboardingStoreError() },
    markCompleted: { throw UnimplementedFirstInstallOnboardingStoreError() }
  )
}

public extension DependencyValues {
  var firstInstallOnboardingStore: FirstInstallOnboardingStore {
    get { self[FirstInstallOnboardingStoreDependency.self] }
    set { self[FirstInstallOnboardingStoreDependency.self] = newValue }
  }
}

private struct UnimplementedFirstInstallOnboardingStoreError: Error {}
