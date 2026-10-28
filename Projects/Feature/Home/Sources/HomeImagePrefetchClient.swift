import Dependencies
import Foundation
import Kingfisher

struct HomeImagePrefetchClient: Sendable {
  var start: @Sendable ([URL]) async -> Void
  var stop: @Sendable () async -> Void
}

extension HomeImagePrefetchClient: DependencyKey {
  static let testValue = Self(start: { _ in }, stop: {})

  static let liveValue: Self = {
    let worker = HomeImagePrefetchWorker()
    return Self(
      start: { urls in await worker.start(urls) },
      stop: { await worker.stop() }
    )
  }()
}

extension DependencyValues {
  var homeImagePrefetchClient: HomeImagePrefetchClient {
    get { self[HomeImagePrefetchClient.self] }
    set { self[HomeImagePrefetchClient.self] = newValue }
  }
}

private actor HomeImagePrefetchWorker {
  private var current: ImagePrefetcher?

  func start(_ urls: [URL]) {
    guard !Task.isCancelled else { return }
    current?.stop()
    guard !urls.isEmpty else {
      current = nil
      return
    }
    let prefetcher = ImagePrefetcher(urls: urls)
    prefetcher.maxConcurrentDownloads = 3
    current = prefetcher
    prefetcher.start()
  }

  func stop() {
    guard !Task.isCancelled else { return }
    current?.stop()
    current = nil
  }
}
