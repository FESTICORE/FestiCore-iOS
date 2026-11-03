import APIEndpoint
import FestiCoreNetworkInterface
import Foundation
import Testing

@Suite("내 알림 요청 계약")
struct UserNotificationRequestTests {
  private let baseURL = URL(string: "https://festicore.test")!
  private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  @Test func listUsesAuthenticatedGetAndEncodesCursor() throws {
    let request = UserNotificationRequest.list(before: "2026-11-04T00:00:00.000Z|ntf_abc", sessionID: sessionID)
    let url = try #require(request.asURLRequest(baseURL: baseURL).url)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(components.path == "/api/v1/me/notifications")
    #expect(components.queryItems?.first?.name == "before")
    #expect(components.queryItems?.first?.value == "2026-11-04T00:00:00.000Z|ntf_abc")
    #expect(request.method.rawValue == "GET")
    #expect(request.authorization == .sessionBound(sessionID))
    #expect(request.maxRetryAttempts == 0)
  }

  @Test func unreadCountUsesAuthenticatedGet() throws {
    let request = UserNotificationRequest.unreadCount(sessionID: sessionID)
    let url = try #require(request.asURLRequest(baseURL: baseURL).url)

    #expect(url.absoluteString == "https://festicore.test/api/v1/me/notifications/unread-count")
    #expect(request.method.rawValue == "GET")
    #expect(request.authorization == .sessionBound(sessionID))
    #expect(request.parameters == nil)
  }

  @Test(arguments: [true, false])
  func mutationsUsePostJSONBody(isRead: Bool) throws {
    let body = UserNotificationIDsBody(ids: ["ntf_0123456789abcdef0123456789abcdef"])
    let request = isRead
      ? UserNotificationRequest.read(body: body, sessionID: sessionID)
      : UserNotificationRequest.delete(body: body, sessionID: sessionID)
    let encoded = try request.asURLRequest(baseURL: baseURL)

    let path = isRead ? "read" : "delete"
    #expect(encoded.url?.absoluteString == "https://festicore.test/api/v1/me/notifications/\(path)")
    #expect(encoded.httpMethod == "POST")
    #expect(encoded.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(try JSONDecoder().decode([String: [String]].self, from: #require(encoded.httpBody))["ids"] == body.ids)
    #expect(request.authorization == .sessionBound(sessionID))
  }
}
