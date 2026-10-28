//
//  AuthAPITests.swift
//  FestiCoreAPI
//
//  Created by FestiCore on 10/29/26.
//

import Testing

import FestiCoreAPI

@Suite("인증 API 경로")
struct AuthAPITests {
  @Test("로그인·갱신·로그아웃 경로를 선언한다")
  func paths() {
    #expect(AuthAPI.allCases == [.login, .refresh, .logout])
    #expect(AuthAPI.login.path == "api/v1/auth/login")
    #expect(AuthAPI.refresh.path == "api/v1/auth/refresh")
    #expect(AuthAPI.logout.path == "api/v1/auth/logout")
  }
}
