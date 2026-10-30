//
//  AuthAPITests.swift
//  API
//
//  Created by FestiCore on 10/29/26.
//

import Testing

import API

@Suite("인증 API 경로")
struct AuthAPITests {
  @Test("로그인·갱신·로그아웃·탈퇴 경로를 선언한다")
  func paths() {
    #expect(AuthAPI.allCases == [.login, .refresh, .logout, .me, .withdraw])
    #expect(FestiCoreDomain.auth.path == "api/v1/auth")
    #expect(FestiCoreDomain.me.path == "api/v1/me")
    #expect(AuthAPI.login.path == "api/v1/auth/login")
    #expect(AuthAPI.refresh.path == "api/v1/auth/refresh")
    #expect(AuthAPI.logout.path == "api/v1/auth/logout")
    #expect(AuthAPI.me.path == FestiCoreDomain.me.path)
    #expect(AuthAPI.withdraw.path == FestiCoreDomain.me.path)
  }
}
