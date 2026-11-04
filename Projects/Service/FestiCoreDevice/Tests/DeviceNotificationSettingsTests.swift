//
//  DeviceNotificationSettingsTests.swift
//  FestiCoreDeviceTests
//
//  Created by FestiCore on 11/3/26.
//

import Alamofire
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import FestiCoreDevice

@Suite("기기 알림 설정")
struct DeviceNotificationSettingsTests {
  @Test("계정에 묶인 기기는 사용자 세션으로 설정을 요청한다")
  func boundDeviceUsesUserSession() {
    let sessionID = UUID()
    let request = DeviceNotificationSettingsRequest(
      operation: .fetch,
      deviceAuthorization: DeviceAuthorization(
        deviceID: "device-a",
        sessionID: sessionID
      )
    )

    #expect(request.authorization == .sessionBound(sessionID))
    #expect(request.headers.value(for: "X-Device-Id") == "device-a")
    #expect(request.headers.value(for: "Authorization") == nil)
  }

  @Test("설정 조회는 기기 토큰으로 GET 요청을 보내고 응답을 그대로 옮긴다")
  func fetchSendsDeviceAuthorization() async throws {
    let client = SettingsStubClient()
    let service = NetworkDeviceNotificationSettingsService(client: client, registration: RegisteredDevice())

    let settings = try await service.settings()

    let request = try #require(client.requests.first)
    #expect(request.path == "api/v1/devices/notification-settings")
    #expect(request.method == .get)
    #expect(request.deviceID == "device-a")
    #expect(request.bearer == "Bearer device-token")
    #expect(request.body == nil)
    #expect(settings == DeviceNotificationSettings(
      flagStatus: true, crewStatus: false, crewGather: true,
      setReminders: true, homecoming: false, packUpdates: true
    ))
  }

  @Test("변경 요청은 바뀐 항목만 PUT 본문에 담는다")
  func updateSendsOnlyChangedFields() async throws {
    let client = SettingsStubClient()
    let service = NetworkDeviceNotificationSettingsService(client: client, registration: RegisteredDevice())

    _ = try await service.update(DeviceNotificationSettingsChange(crewStatus: true, packUpdates: false))

    let request = try #require(client.requests.first)
    #expect(request.method == .put)
    #expect(request.body?.keys.sorted() == ["crewStatus", "packUpdates"])
    #expect(request.body?["crewStatus"] as? Bool == true)
    #expect(request.body?["packUpdates"] as? Bool == false)
  }

  @Test("기기 등록 정보가 없으면 요청하지 않고 오류를 알린다")
  func missingRegistrationFailsWithoutRequest() async {
    let client = SettingsStubClient()
    let service = NetworkDeviceNotificationSettingsService(client: client, registration: RegisteredDevice(isRegistered: false))

    await #expect(throws: DeviceNotificationSettingsError.deviceNotRegistered) { try await service.settings() }
    #expect(client.requests.isEmpty)
  }

  @Test("성공 코드가 아니면 잘못된 응답으로 처리한다")
  func nonSuccessCodeIsInvalidResponse() async {
    let service = NetworkDeviceNotificationSettingsService(
      client: SettingsStubClient(code: "FAILED"), registration: RegisteredDevice()
    )

    await #expect(throws: DeviceNotificationSettingsError.invalidResponse) {
      try await service.update(DeviceNotificationSettingsChange(flagStatus: false))
    }
  }
}

private struct RegisteredDevice: DeviceRegistrationService {
  var isRegistered = true

  func installationDeviceID() async throws -> String { "device-a" }

  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    DeviceAuthorization(deviceID: "device-a", bearerToken: "device-token")
  }

  func authorization() async throws -> DeviceAuthorization? {
    isRegistered ? DeviceAuthorization(deviceID: "device-a", bearerToken: "device-token") : nil
  }
}

private final class SettingsStubClient: FestiCoreRequestClient, @unchecked Sendable {
  struct Captured {
    let path: String
    let method: HTTPMethod
    let deviceID: String?
    let bearer: String?
    let body: [String: Any]?
  }

  private let lock = NSLock()
  private let code: String
  private var captured: [Captured] = []

  init(code: String = "SUCCESS") { self.code = code }

  var requests: [Captured] { lock.withLock { captured } }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as _: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let body = request.parameters
      .flatMap { try? JSONEncoder().encode(AnyEncodable($0)) }
      .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    lock.withLock {
      captured.append(Captured(
        path: request.path, method: request.method,
        deviceID: request.headers.value(for: "X-Device-Id"),
        bearer: request.headers.value(for: "Authorization"),
        body: body
      ))
    }
    let response = Data("""
      {"code":"\(code)","message":"성공","data":{"flagStatus":true,"crewStatus":false,"crewGather":true,\
      "setReminders":true,"homecoming":false,"packUpdates":true}}
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

private struct AnyEncodable: Encodable {
  let value: any Encodable

  init(_ value: any Encodable) { self.value = value }

  func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
