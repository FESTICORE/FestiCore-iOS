//
//  MockFestivalImageUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import Foundation

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalImageUseCase: FestivalImageUseCaseInterface {
  private let imageURLHandler: @Sendable (String?) -> URL?
  private let startPrefetchHandler: @Sendable ([URL]) async -> Void
  private let stopPrefetchHandler: @Sendable () async -> Void

  public init(
    imageURL: @escaping @Sendable (String?) -> URL? = { _ in
      reportIssue("festivalImageUseCase.imageURL 미등록")
      return nil
    },
    startPrefetch: @escaping @Sendable ([URL]) async -> Void = { _ in
      reportIssue("festivalImageUseCase.startPrefetch 미등록")
    },
    stopPrefetch: @escaping @Sendable () async -> Void = {
      reportIssue("festivalImageUseCase.stopPrefetch 미등록")
    }
  ) {
    self.imageURLHandler = imageURL
    self.startPrefetchHandler = startPrefetch
    self.stopPrefetchHandler = stopPrefetch
  }

  public func imageURL(for value: String?) -> URL? {
    imageURLHandler(value)
  }

  public func startPrefetch(_ urls: [URL]) async {
    await startPrefetchHandler(urls)
  }

  public func stopPrefetch() async {
    await stopPrefetchHandler()
  }
}
