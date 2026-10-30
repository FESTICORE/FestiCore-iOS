//
//  AuthRequestTests.swift
//  APIEndpoint
//
//  Created by FestiCore on 10/29/26.
//

import Foundation
import Testing

import APIEndpoint
import FestiCoreNetworkInterface

@Suite("인증 요청 계약")
struct AuthRequestTests {
  private let baseURL = URL(string: "https://festicore-dev.up.railway.app")!

  @Test("Google 로그인은 공개 경로와 JSON 본문을 사용한다")
  func googleLogin() throws {
    let endpoint = AuthRequest.login(body: AuthLoginBody(
      provider: "google", token: "sample-id-token", authorizationCode: nil, name: nil
    ))
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.path == "/api/v1/auth/login")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(endpoint.authorization == .none)
    #expect(endpoint.maxRetryAttempts == 0)
    let body = try jsonBody(request)
    #expect(body["provider"] as? String == "google")
    #expect(body["token"] as? String == "sample-id-token")
    #expect(body["authorizationCode"] == nil)
    #expect(body["name"] == nil)
  }

  @Test("Apple 로그인은 인가 코드와 이름을 보낸다")
  func appleLogin() throws {
    let endpoint = AuthRequest.login(body: AuthLoginBody(
      provider: "apple", token: "sample-id-token", authorizationCode: "sample-code", name: "테스터"
    ))
    let request = try endpoint.asURLRequest(baseURL: baseURL)
    let body = try jsonBody(request)

    #expect(request.url?.path == "/api/v1/auth/login")
    #expect(body["provider"] as? String == "apple")
    #expect(body["authorizationCode"] as? String == "sample-code")
    #expect(body["name"] as? String == "테스터")
  }

  @Test("토큰 갱신은 인증 없이 refreshToken 본문을 보낸다")
  func refresh() throws {
    let endpoint = AuthRequest.refresh(refreshToken: "sample-refresh-token")
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.path == "/api/v1/auth/refresh")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(endpoint.authorization == .none)
    #expect(endpoint.maxRetryAttempts == 0)
    let body = try jsonBody(request)
    #expect(body.count == 1)
    #expect(body["refreshToken"] as? String == "sample-refresh-token")
  }

  @Test("로그아웃은 자동 인증을 사용하고 본문이 없다")
  func logout() throws {
    let endpoint = AuthRequest.logout
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.path == "/api/v1/auth/logout")
    #expect(request.httpMethod == "POST")
    #expect(endpoint.authorization == .automatic)
    #expect(endpoint.maxRetryAttempts == 0)
    #expect(request.httpBody == nil)
    #expect(request.url?.query == nil)
  }

  @Test("회원 탈퇴는 인증된 DELETE 요청이며 본문과 재시도가 없다")
  func withdraw() throws {
    let endpoint = AuthRequest.withdraw
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.path == "/api/v1/me")
    #expect(request.httpMethod == "DELETE")
    #expect(endpoint.authorization == .automatic)
    #expect(endpoint.maxRetryAttempts == 0)
    #expect(endpoint.parameters == nil)
    #expect(request.httpBody == nil)
    #expect(request.url?.query == nil)
    let _: AuthRequest.Response = FestiCoreEmptyResponse()
  }

  @Test("내 프로필은 인증된 GET 요청이다")
  func me() throws {
    let endpoint = AuthRequest.me
    let request = try endpoint.asURLRequest(baseURL: baseURL)
    #expect(request.url?.path == "/api/v1/me")
    #expect(request.httpMethod == "GET")
    #expect(endpoint.authorization == .automatic)
    #expect(endpoint.maxRetryAttempts == 0)
    #expect(request.httpBody == nil)
  }

  @Test("프로필 수정은 약관 버전과 선택 동의를 PATCH 본문에 보낸다")
  func updateMe() throws {
    let endpoint = AuthRequest.updateMe(body: AuthProfileUpdateBody(
      nickname: "축제관객", termsVersion: "2026-10", pushOptIn: false
    ))
    let request = try endpoint.asURLRequest(baseURL: baseURL)
    #expect(request.url?.path == "/api/v1/me")
    #expect(request.httpMethod == "PATCH")
    #expect(endpoint.authorization == .automatic)
    #expect(endpoint.maxRetryAttempts == 0)
    let body = try jsonBody(request)
    #expect(body["nickname"] as? String == "축제관객")
    #expect((body["acceptTerms"] as? [String: String])?["version"] == "2026-10")
    #expect(body["pushOptIn"] as? Bool == false)
  }

  private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
    let data = try #require(request.httpBody)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
