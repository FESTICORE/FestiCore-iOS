//
//  FestivalNotificationSettingsUseCaseTests.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalNotificationSettingsUseCaseTests {
  private let body = Data(#"{"code":"SUCCESS","message":"OK","data":{"flagStatus":true,"crewStatus":false,"crewGather":true,"setReminders":true,"homecoming":false,"packUpdates":true}}"#.utf8)

  @Test func fetchAndUpdateUseDeviceHeaders() async throws {
    let client = SettingsClient(body: body)
    let useCase = withDependencies {
      $0.networkClient = client
      $0.deviceRegistrationService = StubDeviceService(authorization: .init(deviceID: "device-1", bearerToken: "token-1"))
    } operation: {
      FestivalNotificationSettingsUseCaseImpl()
    }

    let settings = try await useCase.settings()
    #expect(settings == FestivalNotificationSettings(crewStatus: false, homecoming: false))
    var request = await client.requests.last
    #expect(request?.path == "api/v1/devices/notification-settings")
    #expect(request?.method == "GET")
    #expect(request?.headers["X-Device-Id"] == "device-1")
    #expect(request?.headers["Authorization"] == "Bearer token-1")
    #expect(request?.isPublic == true)

    _ = try await useCase.updateSettings(FestivalNotificationSettings(packUpdates: false))
    request = await client.requests.last
    #expect(request?.method == "PUT")
    #expect(request?.body?.contains(#""packUpdates":false"#) == true)
  }

  @Test func unregisteredDeviceFailsBeforeNetwork() async {
    let client = SettingsClient(body: body)
    let useCase = withDependencies {
      $0.networkClient = client
      $0.deviceRegistrationService = StubDeviceService(authorization: nil)
    } operation: {
      FestivalNotificationSettingsUseCaseImpl()
    }

    await #expect(throws: FestivalNotificationSettingsError.deviceNotRegistered) { try await useCase.settings() }
    #expect(await client.requests.isEmpty)
  }
}

private struct StubDeviceService: DeviceRegistrationService {
  let authorization: DeviceAuthorization?

  func installationDeviceID() async throws -> String { authorization?.deviceID ?? "" }
  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    throw FestivalNotificationSettingsError.deviceNotRegistered
  }
  func authorization() async throws -> DeviceAuthorization? { authorization }
}

private actor SettingsClient: FestiCoreNetworkClient {
  struct Request: Sendable {
    let path: String
    let method: String
    let headers: [String: String]
    let isPublic: Bool
    let body: String?
  }

  let body: Data
  private(set) var requests: [Request] = []

  init(body: Data) {
    self.body = body
  }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let encoded = request.parameters.flatMap { try? encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) }
    requests.append(Request(
      path: request.path,
      method: request.method.rawValue,
      headers: Dictionary(request.headers.map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first }),
      isPublic: request.authorization == .none,
      body: encoded
    ))
    do { return try JSONDecoder().decode(type, from: body) }
    catch { throw .decoding(.failed(error)) }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.invalidURL)
  }

  func sendResponse<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }

  func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.invalidURL)
  }

  func upload(_ request: some FestiCoreFileUploadRequest) async throws(FestiCoreNetworkError) {
    throw .request(.invalidURL)
  }
}
