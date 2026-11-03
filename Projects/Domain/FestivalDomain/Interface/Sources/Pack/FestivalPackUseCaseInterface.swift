//
//  FestivalPackUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestiCorePackInterface

/// 축제 팩을 기기 캐시에서 읽고 서버 변경을 따라간다.
public protocol FestivalPackUseCaseInterface: Sendable {
  /// 무결성 검증을 통과한 로컬 팩 목록. 네트워크에 연결하지 않는다.
  func cachedPacks() async throws -> [CachedFestivalPack]
  /// 연결이 끊어지면 `.reconnecting`을 알리고 다시 요청한다.
  func packUpdates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error>
  /// 사용자가 요청한 단발 팩 다운로드. 청크 바이트와 캐시 저장 완료를 순서대로 보낸다.
  func downloadPack(for festivalID: String) -> AsyncThrowingStream<PackDownloadEvent, Error>
}

public enum FestivalPackUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalPackUseCaseInterface { MockFestivalPackUseCase() }
  public static var previewValue: any FestivalPackUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalPackUseCase: any FestivalPackUseCaseInterface {
    get { self[FestivalPackUseCaseDependency.self] }
    set { self[FestivalPackUseCaseDependency.self] = newValue }
  }
}
