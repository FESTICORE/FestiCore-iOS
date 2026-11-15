import Foundation
import Testing
@testable import FestiCoreUtility

struct RemoteNotificationEnrichmentTests {
  @Test func readsFestivalThreadSubtitleAndHTTPSImage() {
    let enrichment = RemoteNotificationEnrichment(userInfo: [
      "festivalId": "fst_abc",
      "festivalName": " 원더리벳 2026 ",
      "imageUrl": "https://cdn.example.com/poster.jpg",
    ])

    #expect(enrichment.threadIdentifier == "festival.fst_abc")
    #expect(enrichment.subtitle == "원더리벳 2026")
    #expect(enrichment.imageURL == URL(string: "https://cdn.example.com/poster.jpg"))
  }

  @Test func ignoresMissingBlankAndNonHTTPSValues() {
    let enrichment = RemoteNotificationEnrichment(userInfo: [
      "festivalId": "  ",
      "festivalName": 3,
      "imageUrl": "http://cdn.example.com/poster.jpg",
    ])

    #expect(enrichment.threadIdentifier == nil)
    #expect(enrichment.subtitle == nil)
    #expect(enrichment.imageURL == nil)
  }

  @Test func keepsValuesTheServerAlreadySet() {
    let enrichment = RemoteNotificationEnrichment(userInfo: [
      "festivalId": "fst_abc",
      "festivalName": "원더리벳 2026",
    ])

    #expect(enrichment.threadIdentifier(current: "festival.set_reminder:1") == nil)
    #expect(enrichment.threadIdentifier(current: "") == "festival.fst_abc")
    #expect(enrichment.subtitle(current: "메인 무대") == nil)
    #expect(enrichment.subtitle(current: "") == "원더리벳 2026")
  }

  @Test func acceptsOnlyAttachmentImageTypes() {
    #expect(RemoteNotificationEnrichment.attachmentFileExtension(mimeType: "image/jpeg") == "jpg")
    #expect(RemoteNotificationEnrichment.attachmentFileExtension(mimeType: "IMAGE/PNG") == "png")
    #expect(RemoteNotificationEnrichment.attachmentFileExtension(mimeType: "image/gif") == "gif")
    #expect(RemoteNotificationEnrichment.attachmentFileExtension(mimeType: "image/webp") == nil)
    #expect(RemoteNotificationEnrichment.attachmentFileExtension(mimeType: nil) == nil)
  }
}
