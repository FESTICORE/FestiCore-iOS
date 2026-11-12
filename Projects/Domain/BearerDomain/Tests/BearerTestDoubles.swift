//
//  BearerTestDoubles.swift
//  BearerDomainTests
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import FestiCorePackInterface
import Foundation
import Testing

/// 보낸 요청을 기록하고 정해 둔 응답을 돌려주는 네트워크 대역
actor RecordingClient: FestiCoreNetworkClient {
  struct Sent: Sendable {
    let path: String
    let method: String
    let headers: [String: String]
    let authorization: FestiCoreAuthorization
    let body: Data?
    let parts: [FestiCoreMultipartPart]
  }

  private let result: Result<FestiCoreHTTPResponse, FestiCoreNetworkError>
  /// 경로별 응답. 비어 있으면 모든 요청에 `result`를 돌려준다.
  private var routes: [String: FestiCoreHTTPResponse] = [:]
  private(set) var sent: [Sent] = []

  init(status: Int = 200, json: String) {
    result = .success(FestiCoreHTTPResponse(statusCode: status, data: Data(json.utf8)))
  }

  init(error: FestiCoreNetworkError) {
    result = .failure(error)
  }

  /// 경로마다 다른 응답을 준다. 등록하지 않은 경로는 요청 오류다.
  init(routes: [String: (status: Int, json: String)]) {
    result = .failure(.request(.invalidURL))
    self.routes = routes.mapValues {
      FestiCoreHTTPResponse(
        statusCode: $0.status,
        data: Data($0.json.utf8)
      )
    }
  }

  var last: Sent? { sent.last }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let response = try record(request)
    guard (200 ..< 300).contains(response.statusCode) else {
      throw .response(ResponseError(httpStatus: response.statusCode, code: Self.code(in: response.data)))
    }
    if response.data.isEmpty, let empty = FestiCoreEmptyResponse() as? T { return empty }
    do { return try JSONDecoder().decode(type, from: response.data) }
    catch { throw .decoding(.failed(error)) }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    try await send(request, as: R.Response.self)
  }

  func sendResponse<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    try record(request)
  }

  func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    sent.append(Sent(
      path: request.path,
      method: request.method.rawValue,
      headers: request.headers.dictionary,
      authorization: request.authorization,
      body: nil,
      parts: request.parts
    ))
    let response = try result.get()
    guard (200 ..< 300).contains(response.statusCode) else {
      throw .response(ResponseError(httpStatus: response.statusCode, code: Self.code(in: response.data)))
    }
    do { return try JSONDecoder().decode(R.Response.self, from: response.data) }
    catch { throw .decoding(.failed(error)) }
  }

  func upload(_ request: some FestiCoreFileUploadRequest) async throws(FestiCoreNetworkError) {
    Issue.record("사용하지 않는 요청")
    throw .request(.invalidURL)
  }

  private func record<R: FestiCoreDataRequest>(_ request: R) throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    let urlRequest = try? request.asURLRequest(baseURL: URL(string: "https://festicore.test")!)
    sent.append(Sent(
      path: request.path,
      method: request.method.rawValue,
      headers: request.headers.dictionary,
      authorization: request.authorization,
      body: urlRequest?.httpBody,
      parts: []
    ))
    if let routed = routes[request.path] { return routed }
    return try result.get()
  }

  private static func code(in data: Data) -> String? {
    (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["code"] as? String
  }
}

actor StubAuthService: AuthService {
  let loggedIn: Bool
  let sessionID = UUID()
  private(set) var userID: String?

  init(loggedIn: Bool = true, userID: String? = "usr_me") {
    self.loggedIn = loggedIn
    self.userID = userID
  }

  private var isHeld = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func setUserID(_ userID: String?) { self.userID = userID }

  var waiterCount: Int { waiters.count }

  /// 다음 사용자 조회를 release까지 붙잡는다.
  func hold() { isHeld = true }

  func release() {
    isHeld = false
    waiters.forEach { $0.resume() }
    waiters = []
  }

  var isLoggedIn: Bool { loggedIn }
  var refreshToken: String? { nil }
  var currentUserID: String? {
    get async {
      if isHeld { await withCheckedContinuation { waiters.append($0) } }
      return userID
    }
  }
  var authenticatedSessionID: UUID? { loggedIn ? sessionID : nil }
  var hasPendingLocalClear: Bool { false }
  var hasUnconfirmedRevocation: Bool { false }
  var hasPendingSignOutCleanup: Bool { false }
  var hasPendingWithdrawalAuthorizationCleanup: Bool { false }
  var hasPendingWithdrawalCleanup: Bool { false }
  func stageSession(accessToken: String, refreshToken: String) -> UUID { UUID() }
  func commitSession(_ id: UUID) -> Bool { false }
  func discardSession(_ id: UUID) -> Bool { false }
  func signOut(ifSession id: UUID) -> Bool { false }
  func rememberUserID(_ userID: String) {}
  func signOut() -> Bool { false }
  func signOut(ifSessionIDMatches sessionID: UUID) -> Bool { false }
  func prepareRevocation(_ kind: AuthRevocationKind, ifSessionIDMatches sessionID: UUID) -> Bool { false }
  func finishRevocationRequest() {}
  func confirmSignOut() -> Bool { false }
  func confirmWithdrawalAuthorizationRejected() -> Bool { false }
  func retryUnconfirmedLocalCleanup() -> Bool { false }
  func completeWithdrawal() -> Bool { false }
}

struct StubDeviceService: DeviceRegistrationService {
  let deviceID: String

  func installationDeviceID() async throws -> String { deviceID }

  func register(_ metadata: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    Issue.record("사용하지 않는 요청")
    throw CancellationError()
  }

  func authorization() async throws -> DeviceAuthorization? { nil }
}

struct StubPackSyncService: PackSyncService {
  let pack: CachedFestivalPack?

  func cachedPack(for festivalID: String) async throws -> CachedFestivalPack? { pack }
  func cachedPacks() async throws -> [CachedFestivalPack] { pack.map { [$0] } ?? [] }
  func sync(for festivalID: String) async throws -> PackSyncResult { throw CancellationError() }
  func updates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    AsyncThrowingStream { $0.finish() }
  }
}
