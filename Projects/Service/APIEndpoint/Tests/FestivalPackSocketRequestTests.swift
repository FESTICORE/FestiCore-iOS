//
//  FestivalPackSocketRequestTests.swift
//  APIEndpoint
//

import APIEndpoint
import FestiCoreNetworkInterface
import Testing

@Suite("팩 WebSocket 요청 계약")
struct FestivalPackSocketRequestTests {
  @Test("공개 팩 채널은 인증 없이 서비스가 직접 재접속한다")
  func publicUpdates() {
    let endpoint = FestivalPackSocketRequest.updates

    #expect(endpoint.path == "api/v1/festivals/updates")
    #expect(endpoint.method == .get)
    #expect(endpoint.authorization == .none)
    #expect(endpoint.maxRetryAttempts == 0)
  }
}
