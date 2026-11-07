//
//  FlagRequestTests.swift
//  APIEndpoint
//
//  Created by FestiCore on 11/3/26.
//

import Foundation
import Testing

import APIEndpoint
import FestiCoreNetworkInterface

@Suite("깃발 기수 요청 계약")
struct FlagRequestTests {
  private let baseURL = URL(string: "https://festicore-dev.up.railway.app")!
  private let sessionID = UUID()

  @Test("기수 상세는 세션에 묶인 GET이며 로컬 캐시를 쓰지 않는다")
  func bearer() throws {
    let endpoint = FlagRequest.bearer(flagID: "flg_1", sessionID: sessionID)
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.absoluteString == "https://festicore-dev.up.railway.app/api/v1/flags/flg_1/bearer")
    #expect(request.httpMethod == "GET")
    #expect(request.httpBody == nil)
    #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    #expect(endpoint.authorization == .sessionBound(sessionID))
    #expect(endpoint.maxRetryAttempts == 0)
  }

  @Test("공개 깃발 상세는 로그인 상태면 토큰을 붙이는 GET이며 재시도하지 않는다")
  func publicDetail() throws {
    let endpoint = PublicFlagRequest.detail(flagID: "flg_1")
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.absoluteString == "https://festicore-dev.up.railway.app/api/v1/flags/flg_1")
    #expect(request.httpMethod == "GET")
    #expect(request.httpBody == nil)
    #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    #expect(endpoint.authorization == .automatic)
    #expect(endpoint.maxRetryAttempts == 0)
  }

  @Test("상태 변경은 멱등키 헤더와 값이 있는 키만 보낸다")
  func status() throws {
    let endpoint = FlagRequest.status(
      flagID: "flg_1",
      body: FlagStatusBody(clientAt: "2026-10-21T00:00:00.000Z", zoneId: "zone_a", activity: "sing"),
      idempotencyKey: "key-1",
      sessionID: sessionID
    )
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.path == "/api/v1/flags/flg_1/status")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == "key-1")
    #expect(endpoint.authorization == .sessionBound(sessionID))
    #expect(endpoint.maxRetryAttempts == 0)
    let body = try jsonBody(request)
    #expect(body.keys.sorted() == ["activity", "clientAt", "zoneId"])
    #expect(body["clientAt"] as? String == "2026-10-21T00:00:00.000Z")
  }

  @Test("프로필 수정은 PATCH이며 비운 소개와 존을 null로 보낸다")
  func profile() throws {
    let endpoint = FlagRequest.updateProfile(
      flagID: "flg_1",
      body: FlagProfileBody(name: "호락호락", bio: nil, tags: ["slam"], planVisible: true, homeZoneId: nil),
      sessionID: sessionID
    )
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.path == "/api/v1/flags/flg_1")
    #expect(request.httpMethod == "PATCH")
    let body = try jsonBody(request)
    #expect(body["name"] as? String == "호락호락")
    #expect(body["bio"] is NSNull)
    #expect(body["homeZoneId"] is NSNull)
    #expect(body["tags"] as? [String] == ["slam"])
    #expect(body["planVisible"] as? Bool == true)
  }

  @Test("코드 등록은 기기 ID 헤더와 축제 ID·코드를 보낸다")
  func claim() throws {
    let endpoint = FlagRequest.claim(
      body: BearerClaimBody(festivalId: "fst_1", code: "ABC234"),
      deviceID: "device-uuid",
      sessionID: sessionID
    )
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.path == "/api/v1/bearer/claim")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "X-Device-Id") == "device-uuid")
    #expect(try jsonBody(request) as? [String: String] == ["festivalId": "fst_1", "code": "ABC234"])
  }

  @Test("공동 기수 초대와 해제 경로·method")
  func coBearers() throws {
    let invite = try FlagRequest.inviteCoBearer(flagID: "flg_1", sessionID: sessionID).asURLRequest(baseURL: baseURL)
    #expect(invite.url?.path == "/api/v1/flags/flg_1/co-bearers/invite")
    #expect(invite.httpMethod == "POST")
    #expect(invite.httpBody == nil)

    let remove = try FlagRequest.removeCoBearer(flagID: "flg_1", userID: "usr_2", sessionID: sessionID)
      .asURLRequest(baseURL: baseURL)
    #expect(remove.url?.path == "/api/v1/flags/flg_1/co-bearers/usr_2")
    #expect(remove.httpMethod == "DELETE")
  }

  @Test("사진 업로드는 photo 필드 하나를 JPEG로 보낸다")
  func photo() {
    let data = Data([0xFF, 0xD8, 0xFF])
    let request = FlagPhotoUploadRequest<FestiCoreEmptyResponse>(flagID: "flg_1", imageData: data, sessionID: sessionID)

    #expect(request.path == "api/v1/flags/flg_1/photo")
    #expect(request.method.rawValue == "POST")
    #expect(request.authorization == .sessionBound(sessionID))
    #expect(request.maxRetryAttempts == 0)
    #expect(request.parts.count == 1)
    let part = request.parts[0]
    #expect(part.name == "photo")
    #expect(part.mimeType == "image/jpeg")
    #expect(part.fileName == "photo.jpg")
    guard case let .data(sent) = part.source else {
      Issue.record("파일 파트는 메모리 데이터여야 한다")
      return
    }
    #expect(sent == data)
  }

  private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
    let data = try #require(request.httpBody)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
