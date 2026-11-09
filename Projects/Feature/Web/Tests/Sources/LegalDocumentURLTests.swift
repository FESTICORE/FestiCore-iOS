import Foundation
import Testing
@testable import Web

struct LegalDocumentURLTests {
  @Test func readsHTTPSBaseURLFromInfoPlist() {
    let url = LegalDocumentURL.baseURL(infoDictionary: [
      "FestiCoreLegalBaseURL": "https://festicore.app/api/v1/legal/"
    ])

    #expect(url?.appending(path: "terms").absoluteString == "https://festicore.app/api/v1/legal/terms")
  }

  @Test func missingOrInvalidValueIsNil() {
    #expect(LegalDocumentURL.baseURL(infoDictionary: nil) == nil)
    #expect(LegalDocumentURL.baseURL(infoDictionary: [:]) == nil)
    #expect(LegalDocumentURL.baseURL(infoDictionary: ["FestiCoreLegalBaseURL": ""]) == nil)
    // xcconfig에 API 호스트가 비어 있으면 호스트 없는 주소가 된다.
    #expect(LegalDocumentURL.baseURL(infoDictionary: ["FestiCoreLegalBaseURL": "https:///api/v1/legal/"]) == nil)
    #expect(LegalDocumentURL.baseURL(infoDictionary: ["FestiCoreLegalBaseURL": "http://festicore.app/api/v1/legal/"]) == nil)
  }
}
