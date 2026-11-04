//
//  MockFestivalPackUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestiCorePackInterface

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalPackUseCase: FestivalPackUseCaseInterface {
  private let cachedPacksHandler: @Sendable () async throws -> [CachedFestivalPack]
  private let packUpdatesHandler: @Sendable (String) -> AsyncThrowingStream<PackSyncResult, Error>
  private let downloadPackHandler: @Sendable (String) -> AsyncThrowingStream<PackDownloadEvent, Error>

  public init(
    cachedPacks: @escaping @Sendable () async throws -> [CachedFestivalPack] = {
      reportIssue("festivalPackUseCase.cachedPacks 미등록")
      throw FestivalUseCaseNotRegistered()
    },
    packUpdates: @escaping @Sendable (String) -> AsyncThrowingStream<PackSyncResult, Error> = { _ in
      reportIssue("festivalPackUseCase.packUpdates 미등록")
      return AsyncThrowingStream { $0.finish(throwing: FestivalUseCaseNotRegistered()) }
    },
    downloadPack: @escaping @Sendable (String) -> AsyncThrowingStream<PackDownloadEvent, Error> = { _ in
      reportIssue("festivalPackUseCase.downloadPack 미등록")
      return AsyncThrowingStream { $0.finish(throwing: FestivalUseCaseNotRegistered()) }
    }
  ) {
    self.cachedPacksHandler = cachedPacks
    self.packUpdatesHandler = packUpdates
    self.downloadPackHandler = downloadPack
  }

  public func cachedPacks() async throws -> [CachedFestivalPack] {
    try await cachedPacksHandler()
  }

  public func packUpdates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    packUpdatesHandler(festivalID)
  }

  public func downloadPack(for festivalID: String) -> AsyncThrowingStream<PackDownloadEvent, Error> {
    downloadPackHandler(festivalID)
  }
}
