//
//  MeRequestTests.swift
//  APIEndpoint
//
//  Created by FestiCore on 10/29/26.
//

import Foundation
import Testing

import APIEndpoint
import FestiCoreNetworkInterface

@Suite("내 계정 요청 계약")
struct MeRequestTests {
  @Test("회원 탈퇴는 인증된 DELETE 요청이며 본문과 재시도가 없다")
  func withdraw() throws {
    let endpoint = MeRequest.withdraw
    let request = try endpoint.asURLRequest(
      baseURL: URL(string: "https://festicore-dev.up.railway.app")!
    )

    #expect(request.url?.path == "/api/v1/me")
    #expect(request.httpMethod == "DELETE")
    #expect(endpoint.authorization == .automatic)
    #expect(endpoint.maxRetryAttempts == 0)
    #expect(endpoint.parameters == nil)
    #expect(request.httpBody == nil)
    #expect(request.url?.query == nil)
    let _: MeRequest.Response = FestiCoreEmptyResponse()
  }
}
