import Foundation
import Testing
@testable import Web

struct WebNavigationPolicyTests {
  private let host = "festicore.app"

  @Test func onlySameHostHttpsIsAllowed() {
    #expect(WebNavigationPolicy.decide(request: URL(string: "https://festicore.app/terms"), isNewWindow: false, allowedHost: host) == .allow)
    #expect(WebNavigationPolicy.decide(request: URL(string: "https://FESTICORE.app/privacy"), isNewWindow: false, allowedHost: host) == .allow)
    #expect(WebNavigationPolicy.decide(request: URL(string: "http://festicore.app/terms"), isNewWindow: false, allowedHost: host) == .cancel)
    #expect(WebNavigationPolicy.decide(request: URL(string: "https://evil.example/terms"), isNewWindow: false, allowedHost: host) == .cancel)
    #expect(WebNavigationPolicy.decide(request: URL(string: "mailto:help@festicore.app"), isNewWindow: false, allowedHost: host) == .cancel)
    #expect(WebNavigationPolicy.decide(request: nil, isNewWindow: false, allowedHost: host) == .cancel)
  }

  @Test func newWindowLoadsInPlaceOnlyForSameHostHttps() {
    let same = URL(string: "https://festicore.app/privacy")!
    #expect(WebNavigationPolicy.decide(request: same, isNewWindow: true, allowedHost: host) == .loadInPlace(same))
    #expect(WebNavigationPolicy.decide(request: URL(string: "https://other.app/x"), isNewWindow: true, allowedHost: host) == .cancel)
  }

  @Test func mainFrameErrorStatusIsRejected() {
    #expect(WebNavigationPolicy.acceptsResponse(statusCode: 200, isMainFrame: true))
    #expect(!WebNavigationPolicy.acceptsResponse(statusCode: 404, isMainFrame: true))
    #expect(!WebNavigationPolicy.acceptsResponse(statusCode: 500, isMainFrame: true))
    #expect(WebNavigationPolicy.acceptsResponse(statusCode: 404, isMainFrame: false))
  }
}
