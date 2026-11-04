import Dependencies
import SQLiteData

/// 앱의 도메인 로컬 캐시가 공유하는 SQLite 저장소입니다.
public enum AppDatabaseDependency: TestDependencyKey {
  public static let testValue: (any DatabaseWriter)? = nil
}

public extension DependencyValues {
  var appDatabase: (any DatabaseWriter)? {
    get { self[AppDatabaseDependency.self] }
    set { self[AppDatabaseDependency.self] = newValue }
  }
}
