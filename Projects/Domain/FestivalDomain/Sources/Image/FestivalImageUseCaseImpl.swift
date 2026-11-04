//
//  FestivalImageUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface
import Foundation

/// 이미지 URL 검증과 미리 받기를 조합한다.
public struct FestivalImageUseCaseImpl: FestivalImageUseCaseInterface {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalImagePrefetchClient) private var prefetchClient

  public init() {}

  /// 원본 문자열에서 사용 가능한 이미지 URL을 고른다.
  public func imageURL(for value: String?) -> URL? {
    catalogService.imageURL(for: value)
  }

  /// 화면에서 곧 사용할 이미지를 미리 받는다.
  public func startPrefetch(_ urls: [URL]) async {
    await prefetchClient.start(urls)
  }

  /// 실행 중인 이미지 미리 받기를 멈춘다.
  public func stopPrefetch() async {
    await prefetchClient.stop()
  }
}
