//
//  FestivalPackUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation

/// 팩 캐시와 서버 동기화 흐름을 저장소에 위임한다.
public struct FestivalPackUseCaseImpl: FestivalPackUseCaseInterface {
  @Dependency(\.festivalPackSyncRepository) private var packRepository
  @Dependency(\.date) private var date

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

  /// 마지막 날 종료 후 보관 기간이 지난 팩만 지운다. 한 팩을 지우지 못해도 나머지는 계속 확인한다.
  public func deleteExpiredPacks() async throws -> [String] {
    let now = date.now
    var deletedIDs: [String] = []
    for pack in try await packRepository.cachedPacks() {
      try Task.checkCancellation()
      guard let expiresAt = pack.expiresAt, now >= expiresAt else { continue }
      do {
        try await packRepository.deletePack(for: pack.festivalID)
        deletedIDs.append(pack.festivalID)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        // 지우지 못한 팩은 다음 실행 때 다시 확인한다.
      }
    }
    return deletedIDs
  }
}
