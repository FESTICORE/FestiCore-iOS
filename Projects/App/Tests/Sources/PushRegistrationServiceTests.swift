import Foundation
import Testing

import FestiCoreDeviceInterface
@testable import FestiCore

struct PushRegistrationServiceTests {
  @Test("development 환경은 sandbox로 등록하고 토큰을 그대로 전달한다")
  func developmentMapsToSandbox() {
    let metadata = makeMetadata(info: [
      "FestiCoreAPNsEnvironment": "development",
      "CFBundleShortVersionString": "1.2.0"
    ])

    #expect(metadata == DeviceRegistrationMetadata(
      apnsEnvironment: .sandbox,
      apnsToken: "apns-token",
      liveActivityPushToStartToken: "start-token",
      appVersion: "1.2.0",
      osVersion: "18.0",
      locale: "ko-KR",
      timezone: "Asia/Seoul"
    ))
  }

  @Test("production 환경은 production으로 등록한다")
  func productionMapsToProduction() {
    let metadata = makeMetadata(info: [
      "FestiCoreAPNsEnvironment": "production",
      "CFBundleShortVersionString": "1.2.0"
    ])

    #expect(metadata?.apnsEnvironment == .production)
  }

  @Test("토큰이 없어도 메타데이터를 만든다")
  func missingTokensStayNil() {
    let metadata = PushRegistrationService.metadata(
      infoDictionary: [
        "FestiCoreAPNsEnvironment": "production",
        "CFBundleShortVersionString": "1.2.0"
      ],
      apnsToken: nil,
      liveActivityStartToken: nil,
      osVersion: "18.0",
      locale: "ko-KR",
      timezone: "Asia/Seoul"
    )

    #expect(metadata?.apnsToken == nil)
    #expect(metadata?.liveActivityPushToStartToken == nil)
  }

  @Test("APNs 환경 설정이 잘못되면 등록하지 않는다")
  func invalidEnvironmentReturnsNil() {
    let unknown = makeMetadata(info: [
      "FestiCoreAPNsEnvironment": "staging",
      "CFBundleShortVersionString": "1.2.0"
    ])
    let missing = makeMetadata(info: ["CFBundleShortVersionString": "1.2.0"])

    #expect(unknown == nil)
    #expect(missing == nil)
  }

  @Test("앱 버전이 비었거나 없으면 등록하지 않는다")
  func invalidVersionReturnsNil() {
    let empty = makeMetadata(info: [
      "FestiCoreAPNsEnvironment": "development",
      "CFBundleShortVersionString": ""
    ])
    let missing = makeMetadata(info: ["FestiCoreAPNsEnvironment": "development"])

    #expect(empty == nil)
    #expect(missing == nil)
  }
}

private extension PushRegistrationServiceTests {
  func makeMetadata(info: [String: Any]) -> DeviceRegistrationMetadata? {
    return PushRegistrationService.metadata(
      infoDictionary: info,
      apnsToken: "apns-token",
      liveActivityStartToken: "start-token",
      osVersion: "18.0",
      locale: "ko-KR",
      timezone: "Asia/Seoul"
    )
  }
}
