import Dependencies
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import Foundation
import Testing
import UserNotificationDomainInterface
@testable import UserNotificationDomain

@Suite("내 알림 저장소 통신")
struct UserNotificationRepositoryTests {
  private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  @Test func listUsesCurrentSessionAndRejectsInvalidEnvelope() async throws {
    let client = NotificationRecordingClient(
      json: #"{"code":"SUCCESS","message":"OK","data":{"items":[],"nextCursor":null}}"#
    )
    let repository = makeRepository(client: client, sessionID: sessionID)

    let page = try await repository.notifications(before: "opaque-cursor")
    #expect(page.items.isEmpty)
    let sent = try #require(await client.sent.first)
    #expect(sent.path == "api/v1/me/notifications")
    #expect(sent.method == "GET")
    #expect(sent.authorization == .sessionBound(sessionID))

    let invalid = NotificationRecordingClient(
      json: #"{"code":"ERROR","message":"failure","data":{"items":[],"nextCursor":null}}"#
    )
    let invalidRepository = makeRepository(client: invalid, sessionID: sessionID)
    await #expect(throws: UserNotificationError.invalidResponse) {
      try await invalidRepository.notifications(before: nil)
    }
  }

  @Test func missingSessionAndTransportFailurePropagate() async {
    let client = NotificationRecordingClient(json: #"{"code":"SUCCESS","data":{"unreadCount":0}}"#)
    let unauthenticated = makeRepository(client: client, sessionID: nil)
    await #expect(throws: UserNotificationError.unauthenticated) {
      try await unauthenticated.unreadCount()
    }
    #expect(await client.sent.isEmpty)

    let failed = NotificationRecordingClient(error: .request(.invalidURL))
    let repository = makeRepository(client: failed, sessionID: sessionID)
    await #expect(throws: FestiCoreNetworkError.self) {
      try await repository.unreadCount()
    }
  }

  @Test func unreadCountValidatesEnvelopeAndNonnegativeCount() async throws {
    let success = NotificationRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"unreadCount":3}}"#)
    let repository = makeRepository(client: success, sessionID: sessionID)
    #expect(try await repository.unreadCount() == 3)
    let sent = try #require(await success.sent.first)
    #expect(sent.path == "api/v1/me/notifications/unread-count")
    #expect(sent.authorization == .sessionBound(sessionID))

    for json in [
      #"{"code":"ERROR","message":"failure","data":{"unreadCount":3}}"#,
      #"{"code":"SUCCESS","message":"OK","data":{"unreadCount":-1}}"#
    ] {
      let invalid = makeRepository(client: NotificationRecordingClient(json: json), sessionID: sessionID)
      await #expect(throws: UserNotificationError.invalidResponse) {
        try await invalid.unreadCount()
      }
    }
  }

  @Test func readAndDeleteAccept204AndSplitAtBackendLimit() async throws {
    let client = NotificationRecordingClient(status: 204, json: "")
    let repository = makeRepository(client: client, sessionID: sessionID)
    let ids = (0..<101).map { "ntf_\($0)" }

    try await repository.markRead(ids: ids)
    try await repository.delete(ids: ids)

    let sent = await client.sent
    #expect(sent.map(\.path) == [
      "api/v1/me/notifications/read", "api/v1/me/notifications/read",
      "api/v1/me/notifications/delete", "api/v1/me/notifications/delete"
    ])
    #expect(sent.allSatisfy { $0.method == "POST" && $0.authorization == .sessionBound(sessionID) })
    let batches = try sent.map { try JSONDecoder().decode([String: [String]].self, from: #require($0.body))["ids"] }
    #expect(batches.map { $0?.count } == [100, 1, 100, 1])
  }

  private func makeRepository(client: NotificationRecordingClient, sessionID: UUID?) -> UserNotificationRepositoryImpl {
    withDependencies {
      $0.networkClient = client
      $0.authService = NotificationAuthService(sessionID: sessionID)
    } operation: {
      UserNotificationRepositoryImpl()
    }
  }
}

private actor NotificationRecordingClient: FestiCoreNetworkClient {
  struct Sent: Sendable {
    let path: String
    let method: String
    let authorization: FestiCoreAuthorization
    let body: Data?
  }

  private let result: Result<FestiCoreHTTPResponse, FestiCoreNetworkError>
  private(set) var sent: [Sent] = []

  init(status: Int = 200, json: String) {
    result = .success(FestiCoreHTTPResponse(statusCode: status, data: Data(json.utf8)))
  }

  init(error: FestiCoreNetworkError) { result = .failure(error) }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let response = try record(request)
    guard (200..<300).contains(response.statusCode) else {
      throw .response(ResponseError(httpStatus: response.statusCode, code: nil))
    }
    if response.data.isEmpty, let empty = FestiCoreEmptyResponse() as? T { return empty }
    do { return try JSONDecoder().decode(type, from: response.data) } catch {
      throw .decoding(.failed(error))
    }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    try await send(request, as: R.Response.self)
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    try record(request)
  }

  func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.invalidURL)
  }

  func upload(_ request: some FestiCoreFileUploadRequest) async throws(FestiCoreNetworkError) {
    throw .request(.invalidURL)
  }

  private func record<R: FestiCoreDataRequest>(_ request: R) throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    let url = URL(string: "https://festicore.test")!
    sent.append(Sent(
      path: request.path,
      method: request.method.rawValue,
      authorization: request.authorization,
      body: try? request.asURLRequest(baseURL: url).httpBody
    ))
    return try result.get()
  }
}

private struct NotificationAuthService: AuthService {
  let sessionIDValue: UUID?
  init(sessionID: UUID?) { sessionIDValue = sessionID }

  var isLoggedIn: Bool { get async { sessionIDValue != nil } }
  var refreshToken: String? { get async { nil } }
  var currentUserID: String? { get async { nil } }
  var sessionID: UUID { get async { sessionIDValue ?? UUID() } }
  var authenticatedSessionID: UUID? { get async { sessionIDValue } }
  var hasPendingLocalClear: Bool { get async { false } }
  var hasUnconfirmedRevocation: Bool { get async { false } }
  var hasPendingSignOutCleanup: Bool { get async { false } }
  var hasPendingWithdrawalAuthorizationCleanup: Bool { get async { false } }
  var hasPendingWithdrawalCleanup: Bool { get async { false } }
  func stageSession(accessToken: String, refreshToken: String) async -> UUID { UUID() }
  func commitSession(_ id: UUID) async -> Bool { false }
  func discardSession(_ id: UUID) async -> Bool { false }
  func signOut(ifSession id: UUID) async -> Bool { false }
  func rememberUserID(_ userID: String) async {}
  func signOut() async -> Bool { false }
  func signOut(ifSessionIDMatches sessionID: UUID) async -> Bool { false }
  func prepareRevocation(_ kind: AuthRevocationKind, ifSessionIDMatches sessionID: UUID) async -> Bool { false }
  func finishRevocationRequest() async {}
  func confirmSignOut() async -> Bool { false }
  func confirmWithdrawalAuthorizationRejected() async -> Bool { false }
  func retryUnconfirmedLocalCleanup() async -> Bool { false }
  func completeWithdrawal() async -> Bool { false }
}
