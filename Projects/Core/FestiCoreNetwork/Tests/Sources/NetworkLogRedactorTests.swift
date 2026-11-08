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

  @Test("기수 등록 코드와 공동 기수 초대 코드 본문은 로그에서 숨긴다")
  func hidesBearerCodeBodies() {
    let base = "https://festicore-dev.up.railway.app/api/v1"
    #expect(NetworkLogRedactor.hidesBody(for: URL(string: "\(base)/bearer/claim")))
    #expect(NetworkLogRedactor.hidesBody(for: URL(string: "\(base)/flags/flg_1/co-bearers/invite")))
    #expect(!NetworkLogRedactor.hidesBody(for: URL(string: "\(base)/flags/flg_1/bearer")))
    #expect(!NetworkLogRedactor.hidesBody(for: URL(string: "\(base)/flags/flg_1/co-bearers/usr_2")))
  }

  @Test("크루 초대 코드가 담긴 본문은 로그에서 숨기고 상태·집결 본문은 남긴다")
  func hidesCrewInviteBodies() {
    let base = "https://festicore-dev.up.railway.app/api/v1"
    for path in ["crews", "crews/join", "crews/crw_1", "crews/crw_1/invite/rotate"] {
      #expect(NetworkLogRedactor.hidesBody(for: URL(string: "\(base)/\(path)")))
    }
    for path in ["crews/crw_1/status", "crews/crw_1/gather", "crews/invite/K7P2QX"] {
      #expect(!NetworkLogRedactor.hidesBody(for: URL(string: "\(base)/\(path)")))
    }
  }
}
