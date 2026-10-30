//
//  LiveActivityRegistrationTests.swift
//  FestiCoreDeviceTests
//
//  Created by FestiCore on 10/24/26.
//

import Foundation
import Testing
import Alamofire
import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
@testable import FestiCoreDevice

@Suite("Live Activity 서버 등록 계약")
struct LiveActivityRegistrationTests {
  private let credentials = DeviceAuthorization(deviceID: "device-id", bearerToken: "device-token")

  @Test("기본 등록 서비스는 프로세스 종료 대신 오류를 반환한다")
  func unimplementedServiceFailsWithError() async {
    let registration = LiveActivityRegistration(
      festivalID: "fst_abc", activityID: "activity-id", pushToken: "a1b2"
    )
    await #expect(throws: FestiCoreNetworkError.self) {
      try await LiveActivityRegistrationServiceDependency.testValue.register(
        registration, authorization: credentials
      )
    }
  }

  @Test("등록은 기기 인증 헤더와 서버 필드명으로 PUT 요청한다")
  func registerRequest() throws {
    let request = LiveActivityRegistrationRequest(
      method: .put,
      authorization: credentials,
      registration: LiveActivityRegistration(
        festivalID: "fst_abc", activityID: "activity-id", pushToken: "a1b2"
      )
    )

    #expect(request.path == "api/v1/devices/live-activity")
    #expect(request.method == .put)
    #expect(request.authorization == .none)
    #expect(request.headers.value(for: "X-Device-Id") == "device-id")
    #expect(request.headers.value(for: "Authorization") == "Bearer device-token")
    let body = try #require(request.parameters)
    let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: String])
    #expect(fields == ["festivalId": "fst_abc", "activityId": "activity-id", "pushToken": "a1b2"])
  }

  @Test("삭제는 같은 기기 인증으로 바디 없이 DELETE 요청한다")
  func removeRequest() {
    let request = LiveActivityRegistrationRequest(
      method: .delete,
      authorization: credentials,
      registration: nil
    )

    #expect(request.path == "api/v1/devices/live-activity")
    #expect(request.method == .delete)
    #expect(request.authorization == .none)
    #expect(request.headers.value(for: "X-Device-Id") == "device-id")
    #expect(request.parameters == nil)
  }
}
