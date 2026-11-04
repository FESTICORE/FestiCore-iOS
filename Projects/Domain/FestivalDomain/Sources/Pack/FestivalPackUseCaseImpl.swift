//
//  FestivalPackUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomainInterface

/// 팩 캐시와 서버 동기화 흐름을 저장소에 위임한다.
public struct FestivalPackUseCaseImpl: FestivalPackUseCaseInterface {
  @Dependency(\.festivalPackSyncRepository) private var packRepository

  public init() {}

  /// 검증된 로컬 팩 목록을 읽는다.
  public func cachedPacks() async throws -> [CachedFestivalPack] {
    try await packRepository.cachedPacks()
  }

  /// 축제 팩의 변경 알림과 재연결 상태를 전달한다.
  public func packUpdates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    packRepository.packUpdates(for: festivalID)
  }

  /// 다운로드 진행률과 캐시 저장 완료 이벤트를 전달한다.
  public func downloadPack(for festivalID: String) -> AsyncThrowingStream<PackDownloadEvent, Error>
  {
    return packRepository.downloadPack(for: festivalID)
  }
}
