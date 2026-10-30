import Dependencies
import Foundation
import Kingfisher

struct FestivalImagePrefetchClient: Sendable {
  var start: @Sendable ([URL]) async -> Void
  var stop: @Sendable () async -> Void
}

extension FestivalImagePrefetchClient: DependencyKey {
  static let testValue = Self(start: { _ in }, stop: {})

  static let liveValue: Self = {
    let worker = FestivalImagePrefetchWorker()
    return Self(
      start: { urls in await worker.start(urls) },
      stop: { await worker.stop() }
    )
  }()
}

extension DependencyValues {
  var festivalImagePrefetchClient: FestivalImagePrefetchClient {
    get { self[FestivalImagePrefetchClient.self] }
    set { self[FestivalImagePrefetchClient.self] = newValue }
  }
}

private actor FestivalImagePrefetchWorker {
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
