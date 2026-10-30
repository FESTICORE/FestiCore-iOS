//
//  DeviceRegistrationTests.swift
//  FestiCoreDeviceTests
//
//  Created by FestiCore on 10/24/26.
//

import Foundation
import Testing
import Alamofire
@testable import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import FestiCoreStorageInterface
@testable import FestiCoreDevice

@Suite("기기 등록과 인증 정보")
struct DeviceRegistrationTests {
  private let metadata = DeviceRegistrationMetadata(
    apnsEnvironment: .sandbox,
    apnsToken: nil,
    appVersion: "1.0.0",
    osVersion: "18.0",
    locale: "ko-KR",
    timezone: "Asia/Seoul"
  )

  @Test("앱 테스트 호스트의 기본 기기 등록은 외부 요청 없이 오류를 반환한다")
  func defaultRegistrationDoesNotSucceed() async {
    await #expect(throws: TestDeviceRegistrationUnavailable.self) {
      try await DeviceRegistrationServiceDependency.testValue.register(metadata)
    }
  }

  @Test("기본 기기 인증 조회는 미등록 오류를 반환한다")
  func defaultAuthorizationDoesNotSucceed() async {
    await #expect(throws: TestDeviceRegistrationUnavailable.self) {
      _ = try await DeviceRegistrationServiceDependency.testValue.authorization()
    }
  }

  @Test("APNs 권한이 없어도 명시적인 null 토큰으로 등록 요청한다")
  func encodesRegistrationRequest() throws {
    let request = DeviceRegistrationRequest(deviceID: UUID().uuidString, bearerToken: nil, metadata: metadata)
    let body = try #require(request.parameters)
    let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])

    #expect(request.path == "api/v1/devices")
    #expect(request.method == .put)
    #expect(request.authorization == .none)
    #expect(request.headers.value(for: "X-Device-Id") != nil)
    #expect(request.headers.value(for: "Authorization") == nil)
    #expect(fields["apnsToken"] is NSNull)
    #expect(fields["liveActivityPushToStartToken"] is NSNull)
    #expect(fields["apnsEnvironment"] as? String == "sandbox")
    #expect(fields["appVersion"] as? String == "1.0.0")
  }

  @Test("APNs 토큰을 받으면 기기 등록 요청에 전달한다")
  func encodesAPNsToken() throws {
    let metadata = DeviceRegistrationMetadata(
      apnsEnvironment: .sandbox,
      apnsToken: "00abff",
      appVersion: "1.0.0",
      osVersion: "18.0",
      locale: "ko-KR",
      timezone: "Asia/Seoul"
    )
    let request = DeviceRegistrationRequest(deviceID: UUID().uuidString, bearerToken: nil, metadata: metadata)
    let body = try #require(request.parameters)
    let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])

    #expect(fields["apnsToken"] as? String == "00abff")
  }

  @Test("Live Activity 원격 시작 토큰을 기기 등록 요청에 전달한다")
  func encodesPushToStartToken() throws {
    let metadata = DeviceRegistrationMetadata(
      apnsEnvironment: .sandbox,
      apnsToken: nil,
      liveActivityPushToStartToken: "00abff",
      appVersion: "1.0.0",
      osVersion: "18.0",
      locale: "ko-KR",
      timezone: "Asia/Seoul"
    )
    let request = DeviceRegistrationRequest(deviceID: UUID().uuidString, bearerToken: nil, metadata: metadata)
    let body = try #require(request.parameters)
    let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])

    #expect(fields["apnsToken"] is NSNull)
    #expect(fields["liveActivityPushToStartToken"] as? String == "00abff")
  }

  @Test("첫 등록 토큰을 저장하고 다음 등록에 같은 기기 ID와 토큰을 사용한다")
  func persistsDeviceAuthorization() async throws {
    let storage = MemoryDeviceStorage()
    let client = StubDeviceClient()
    let service = NetworkDeviceRegistrationService(client: client, storage: storage)

    let first = try await service.register(metadata)
    #expect(UUID(uuidString: first.deviceID) != nil)
    #expect(first.bearerToken == "issued-token")
    #expect(storage.load(.deviceID) == first.deviceID)
    #expect(storage.load(.deviceAccessToken) == "issued-token")

    let second = try await service.register(metadata)
    #expect(second.deviceID == first.deviceID)
    #expect(second.bearerToken == first.bearerToken)
    #expect(try await service.authorization()?.deviceID == first.deviceID)
    #expect(client.bearerTokens == [nil, "issued-token"])
  }
}

private final class MemoryDeviceStorage: SecureStorage, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [SecureStorageKey: String] = [:]

  func save(_ value: String, for key: SecureStorageKey) { lock.withLock { values[key] = value } }
  func load(_ key: SecureStorageKey) -> String? { lock.withLock { values[key] } }
  func remove(_ key: SecureStorageKey) { _ = lock.withLock { values.removeValue(forKey: key) } }
  func removeAll() { lock.withLock { values.removeAll() } }
}

private final class StubDeviceClient: FestiCoreRequestClient, @unchecked Sendable {
  private let lock = NSLock()
  private var requests: [(deviceID: String, bearerToken: String?)] = []

  var bearerTokens: [String?] { lock.withLock { requests.map { $0.bearerToken } } }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as _: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let deviceID = request.headers.value(for: "X-Device-Id") ?? ""
    let bearer = request.headers.value(for: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
    lock.withLock { requests.append((deviceID, bearer)) }
    let tokenField = bearer == nil ? "\"deviceAccessToken\":\"issued-token\"," : ""
    let response = Data("""
      {"code":"SUCCESS","data":{\(tokenField)"deviceId":"\(deviceID)"}}
      """.utf8)
    do { return try JSONDecoder().decode(T.self, from: response) }
    catch { throw .decoding(.failed(error)) }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    try await send(request, as: R.Response.self)
  }

  func sendResponse<R: FestiCoreDataRequest>(_: R) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }
}
