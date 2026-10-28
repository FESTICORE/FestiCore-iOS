import SwiftUI
import Testing
@testable import FestiCoreAnimation

struct FestiCoreAnimationTests {
  @Test func splashResourceHasExpectedCanvasAndDuration() throws {
    let bundle = Bundle(for: FestiCoreAnimationBundleMarker.self)
    let url = try #require(bundle.url(forResource: FestiCoreAnimationAsset.splash.rawValue, withExtension: "json"))
    let data = try Data(contentsOf: url)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(json["w"] as? Int == 393)
    #expect(json["h"] as? Int == 852)
    #expect(json["fr"] as? Int == 60)
    #expect(json["op"] as? Int == 180)
    let layers = try #require(json["layers"] as? [[String: Any]])
    #expect(layers.contains { $0["nm"] as? String == "Background #111113" && $0["sc"] as? String == "#111113" })
  }

  @Test @MainActor func viewAcceptsCallerBundleAndPausedBinding() {
    let view = FestiCoreAnimationView(name: "loading.gif", bundle: .main, isAnimating: .constant(false))
    let controller = UIHostingController(rootView: view)
    #expect(controller.view != nil)
  }

  @Test @MainActor func durationAcceptsOnlyPositiveFiniteSeconds() {
    let original = FestiCoreLottieView(.asset(name: "missing", bundle: .main))
    let shortened = original.duration(2)

    #expect(original.targetDuration == nil)
    #expect(shortened.targetDuration == 2)
    #expect(shortened.duration(0).targetDuration == 2)
    #expect(shortened.duration(.infinity).targetDuration == 2)
    #expect(shortened.duration(.nan).targetDuration == 2)
    #expect(shortened.speed(for: 6) == 3)
    #expect(shortened.speed(for: .infinity) == 1)
    #expect(original.speedOverride(for: 6) == nil)
    #expect(shortened.speedOverride(for: 6) == 3)
    #expect(shortened.speedOverride(for: .infinity) == nil)
  }

  @Test func remoteSourceRequiresHTTPSAndKeepsExplicitFormat() {
    let url = URL(string: "https://example.com/loading")!
    let json = FestiCoreLottieSource.remote(url: url, format: .json)
    let dotLottie = FestiCoreLottieSource.remote(url: url, format: .dotLottie)

    #expect(json.isValidRemoteSource)
    #expect(dotLottie.isValidRemoteSource)
    #expect(!FestiCoreLottieSource.remote(url: URL(string: "http://example.com/loading")!, format: .json).isValidRemoteSource)
    #expect(!FestiCoreLottieSource.remote(url: URL(fileURLWithPath: "/tmp/loading.json"), format: .json).isValidRemoteSource)

    if case let .remote(_, format) = dotLottie {
      #expect(format == .dotLottie)
    } else {
      Issue.record("원격 소스 형식이 유지되어야 합니다")
    }
  }

  @Test @MainActor func remoteRequestIdentityIncludesURLAndFormat() {
    let url = URL(string: "https://example.com/loading")!
    let view = FestiCoreLottieView(.remote(url: url, format: .json))

    #expect(view.taskID(url: url, format: .json) != view.taskID(url: url, format: .dotLottie))
    #expect(view.taskID(url: url, format: .json) != view.taskID(url: URL(string: "https://example.com/other")!, format: .json))
  }
}
