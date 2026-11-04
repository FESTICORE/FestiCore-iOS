import Dependencies
import FestiCorePackInterface

/// 팩 캐시 조회와 서버 수신 계약.
public protocol FestivalPackSyncRepositoryInterface: Sendable {
  /// 무결성 검증을 마친 로컬 팩 목록을 읽는다.
  func cachedPacks() async throws -> [CachedFestivalPack]
  /// 서버의 팩 변경을 계속 수신하고 재연결 상태를 전한다.
  func packUpdates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error>
  /// 요청한 팩의 다운로드 진행과 저장 결과를 전한다.
  func downloadPack(for festivalID: String) -> AsyncThrowingStream<PackDownloadEvent, Error>
}

public enum FestivalPackSyncRepositoryDependency: TestDependencyKey {
  public static var testValue: any FestivalPackSyncRepositoryInterface {
    return UnregisteredFestivalPackSyncRepository()
  }
  public static var previewValue: any FestivalPackSyncRepositoryInterface { return testValue }
}

extension DependencyValues {
  public var festivalPackSyncRepository: any FestivalPackSyncRepositoryInterface {
    get { self[FestivalPackSyncRepositoryDependency.self] }
    set { self[FestivalPackSyncRepositoryDependency.self] = newValue }
  }
}

/// 팩 저장소를 주입하지 않은 테스트 호출을 오류로 알린다.
private struct UnregisteredFestivalPackSyncRepository: FestivalPackSyncRepositoryInterface {
  func cachedPacks() async throws -> [CachedFestivalPack] {
    reportIssue("festivalPackSyncRepository.cachedPacks 미등록")
    throw FestivalPackError.notRegistered
  }

  func packUpdates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    return AsyncThrowingStream {
      reportIssue("festivalPackSyncRepository.packUpdates 미등록")
      $0.finish(throwing: FestivalPackError.notRegistered)
    }
  }

  func downloadPack(for _: String) -> AsyncThrowingStream<PackDownloadEvent, Error> {
    return AsyncThrowingStream {
      reportIssue("festivalPackSyncRepository.downloadPack 미등록")
      $0.finish(throwing: FestivalPackError.notRegistered)
    }
  }
}
