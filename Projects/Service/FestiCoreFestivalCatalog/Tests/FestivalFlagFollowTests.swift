@testable import FestiCoreFestivalCatalog
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalFlagFollowTests {
  @Test
  func followSendsPutWithIdempotencyKey() async throws {
    let client = FollowStubClient(result: .success(#"{"code":"SUCCESS","message":"OK","data":{"flagId":"flg_a","following":true,"followerCount":3}}"#))
    let service = NetworkFestivalFlagFollowService(client: client, auth: FollowStubAuth(), makeKey: { "key-1" })

    let result = try await service.setFollowing(true, flagID: "flg_a")

    #expect(result == .init(flagID: "flg_a", isFollowing: true, followerCount: 3))
    let request = try #require(await client.requests.first)
    #expect(request.line == "PUT api/v1/flags/flg_a/follow")
    #expect(request.idempotencyKey == "key-1")
    #expect(request.authorization == .automatic)
    #expect(request.maxRetryAttempts == 0)
    #expect(request.hasParameters == false)
  }

  @Test
  func unfollowSendsDeleteWithoutIdempotencyKey() async throws {
    let client = FollowStubClient(result: .success(#"{"code":"SUCCESS","message":"OK","data":{"flagId":"flg_a","following":false,"followerCount":2}}"#))
    let service = NetworkFestivalFlagFollowService(client: client, auth: FollowStubAuth(), makeKey: { "key-1" })

    let result = try await service.setFollowing(false, flagID: "flg_a")

    #expect(result == .init(flagID: "flg_a", isFollowing: false, followerCount: 2))
    let request = try #require(await client.requests.first)
    #expect(request.line == "DELETE api/v1/flags/flg_a/follow")
    #expect(request.idempotencyKey == nil)
  }

  @Test
  func loggedOutUserIsAskedToLoginWithoutRequest() async {
    let client = FollowStubClient(result: .failure(.transport(.notConnected)))
    let service = NetworkFestivalFlagFollowService(client: client, auth: FollowStubAuth(isLoggedIn: false))

    await #expect(throws: FestivalFlagFollowError.loginRequired) {
      try await service.setFollowing(true, flagID: "flg_a")
    }
    #expect(await client.requests.isEmpty)
  }

  @Test(arguments: [
    (FestiCoreNetworkError.response(ResponseError(httpStatus: 401)), FestivalFlagFollowError.loginRequired),
    (.response(ResponseError(httpStatus: 403, code: "TERMS_REQUIRED")), .termsRequired),
    (.response(ResponseError(httpStatus: 404)), .notFound),
    (.response(ResponseError(httpStatus: 409, code: "FOLLOW_LIMIT")), .limitReached),
    (.response(ResponseError(httpStatus: 409, code: "IDEMPOTENCY_CONFLICT")), .unavailable),
    (.response(ResponseError(httpStatus: 500)), .unavailable),
    (.transport(.timedOut), .unavailable),
    (.decoding(.dataMissing), .invalidResponse),
    (.request(.invalidURL), .invalidRequest),
  ])
  func mapsFailures(error: FestiCoreNetworkError, expected: FestivalFlagFollowError) async {
    let client = FollowStubClient(result: .failure(error))
    let service = NetworkFestivalFlagFollowService(client: client, auth: FollowStubAuth())

    await #expect(throws: expected) {
      try await service.setFollowing(true, flagID: "flg_a")
    }
  }

  @Test
  func rejectsResponseForAnotherFlag() async {
    let client = FollowStubClient(result: .success(#"{"code":"SUCCESS","message":"OK","data":{"flagId":"flg_b","following":true,"followerCount":3}}"#))
    let service = NetworkFestivalFlagFollowService(client: client, auth: FollowStubAuth())

    await #expect(throws: FestivalFlagFollowError.invalidResponse) {
      try await service.setFollowing(true, flagID: "flg_a")
    }
  }

  @Test
  func rejectsFlagIDUnsafeForPath() async {
    let client = FollowStubClient(result: .failure(.transport(.notConnected)))
    let service = NetworkFestivalFlagFollowService(client: client, auth: FollowStubAuth())

    await #expect(throws: FestivalFlagFollowError.invalidResponse) {
      try await service.setFollowing(true, flagID: "../flg_a")
    }
    #expect(await client.requests.isEmpty)
  }
}

private struct SentFollowRequest: Sendable {
  let line: String
  let idempotencyKey: String?
  let authorization: FestiCoreAuthorization
  let maxRetryAttempts: Int
  let hasParameters: Bool
}

private actor FollowStubAuth: AuthService {
  private let loggedIn: Bool
  let sessionID = UUID()
  init(isLoggedIn: Bool = true) { loggedIn = isLoggedIn }
  var isLoggedIn: Bool { loggedIn }
  var authenticatedSessionID: UUID? { loggedIn ? sessionID : nil }
  var refreshToken: String? { nil }
  var currentUserID: String? { loggedIn ? "user-a" : nil }

  func stageSession(accessToken _: String, refreshToken _: String) -> UUID { UUID() }
  func commitSession(_: UUID) -> Bool { false }
  func discardSession(_: UUID) -> Bool { false }
  func signOut(ifSession _: UUID) -> Bool { false }
  func signOut(ifSessionIDMatches _: UUID) -> Bool { false }
  func rememberUserID(_: String) {}
  func signOut() {}
}

private actor FollowStubClient: FestiCoreRequestClient {
  private let result: Result<String, FestiCoreNetworkError>
  private(set) var requests: [SentFollowRequest] = []

  init(result: Result<String, FestiCoreNetworkError>) {
    self.result = result
  }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _: R, as _: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    throw .request(.invalidURL)
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    requests.append(.init(
      line: "\(request.method.rawValue) \(request.path)",
      idempotencyKey: request.headers.value(for: "Idempotency-Key"),
      authorization: request.authorization,
      maxRetryAttempts: request.maxRetryAttempts,
      hasParameters: request.parameters != nil
    ))
    switch result {
    case let .success(body):
      guard let response = try? JSONDecoder().decode(R.Response.self, from: Data(body.utf8)) else {
        throw .decoding(.dataMissing)
      }
      return response
    case let .failure(error):
      throw error
    }
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }
}
