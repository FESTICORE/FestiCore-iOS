//
//  FestivalImageUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface
import Foundation

public struct FestivalImageUseCaseImpl: FestivalImageUseCaseInterface {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalImagePrefetchClient) private var prefetchClient

  public init() {}

  public func imageURL(for value: String?) -> URL? {
    catalogService.imageURL(for: value)
  }

  public func startPrefetch(_ urls: [URL]) async {
    await prefetchClient.start(urls)
  }

  public func stopPrefetch() async {
    await prefetchClient.stop()
  }
}
