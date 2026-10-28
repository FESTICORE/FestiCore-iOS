//
//  NetworkLogRedactorTests.swift
//  FestiCoreNetworkTests
//
//  Created by FestiCore on 10/29/26.
//

import Foundation
import Testing
@testable import FestiCoreNetwork

@Suite("네트워크 로그 자격증명 보호")
struct NetworkLogRedactorTests {
  @Test("인증 헤더는 원문 대신 가려진 값으로 기록한다")
  func hidesHeaders() {
    let headers = NetworkLogRedactor.headers([
      "Authorization": "Bearer private-access",
      "Cookie": "session=private-cookie",
      "Content-Type": "application/json"
    ])

    #expect(headers["Authorization"] == "<redacted>")
    #expect(headers["Cookie"] == "<redacted>")
    #expect(headers["Content-Type"] == "application/json")
    #expect(!headers.values.contains { $0.contains("private-") })
  }

  @Test("로그인·갱신·로그아웃 요청과 응답 본문은 로그에서 숨긴다")
  func hidesAuthBodies() {
    for endpoint in ["login", "refresh", "logout", "session/revoke"] {
      let url = URL(string: "https://festicore-dev.up.railway.app/api/v1/auth/\(endpoint)")
      #expect(NetworkLogRedactor.hidesBody(for: url))
    }
    #expect(!NetworkLogRedactor.hidesBody(for: URL(string: "https://festicore-dev.up.railway.app/api/v1/festivals")))
  }
}
