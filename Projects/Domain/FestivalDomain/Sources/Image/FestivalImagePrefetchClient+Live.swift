import Dependencies
import FestivalDomainInterface
import Foundation
import Kingfisher

extension FestivalImagePrefetchClient: DependencyKey {
  public static let liveValue: Self = {
    let worker = FestivalImagePrefetchWorker()
    return Self(
      start: { urls in await worker.start(urls) },
      stop: { await worker.stop() }
    )
  }()
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
