import Testing
@testable import Web

struct WebAccessibilityIDTests {
  @Test func identifiersAreUniqueAndNamespaced() {
    let ids = [WebAccessibilityID.root, WebAccessibilityID.loading, WebAccessibilityID.failure]
    #expect(Set(ids).count == ids.count)
    #expect(ids.allSatisfy { $0.hasPrefix("web.") })
  }
}
