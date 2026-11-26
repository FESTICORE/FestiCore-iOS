//
//  BearerFestivalTransferTests.swift
//  BearerDomainTests
//
//  Created by FestiCore on 11/26/26.
//

import BearerDomainInterface
import Dependencies
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import BearerDomain

/// `POST flags/{id}/festival-transfer`(백엔드 #409). 응답은 서버 OpenAPI 예시와 같은 가짜 값이다.
@Suite("깃발 축제 이동")
struct BearerFestivalTransferTests {
  private let baseURL = URL(string: "https://festicore.test")

  @Test("축제 이동은 멱등키 헤더를 붙인 세션 POST이며 옮긴 결과를 돌려준다")
  func transferFestival() async throws {
    let auth = StubAuthService()
    let client = RecordingClient(json: Self.transferJSON)
    let repository = makeRepository(
      client: client,
      auth: auth
    )

    let result = try await repository.transferFestival(Self.request)

    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/flags/flg_123/festival-transfer")
    #expect(sent.method == "POST")
    #expect(sent.headers["Idempotency-Key"] == "transfer-1")
    #expect(sent.authorization == .sessionBound(await auth.sessionID))
    let body = try #require(sent.body.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
    #expect(body.keys.sorted() == ["fromFestivalId", "toFestivalId"])
    #expect(body["fromFestivalId"] as? String == "fst_old")
    #expect(body["toFestivalId"] as? String == "fst_new")
    #expect(result.flagID == "flg_123")
    #expect(result.previousFestivalID == "fst_old")
    #expect(result.festivalID == "fst_new")
    #expect(result.profile.name == "푸른 깃발")
    #expect(result.profile.followerCount == 12)
    #expect(result.profile.plan == [])
    #expect(result.profile.homeZoneID == nil)
  }

  @Test("축제 이동 오류는 축제 불일치·공동 기수·기수 모드 꺼짐을 따로 나눈다")
  func transferFailures() async {
    let cases: [(Int, String, BearerError)] = [
      (400, "VALIDATION", .invalidRequest),
      (401, "UNAUTHORIZED", .notAuthenticated),
      (403, "FLAG_NOT_BEARER", .notBearer),
      (403, "FLAG_NOT_OWNER", .notOwner),
      (403, "TERMS_REQUIRED", .termsRequired),
      (404, "NOT_FOUND", .notFound),
      (409, "FESTIVAL_MISMATCH", .festivalMismatch),
      (409, "FLAG_HAS_CO_BEARERS", .hasCoBearers),
      (409, "BEARER_LIMIT", .bearerLimit),
      (409, "FLAG_NAME_TAKEN", .nameTaken),
      (409, "BEARER_MODE_OFF", .bearerModeOff),
      (409, "IDEMPOTENCY_CONFLICT", .conflict),
    ]
    for testCase in cases {
      let repository = makeRepository(client: RecordingClient(
        status: testCase.0,
        json: #"{"code":"\#(testCase.1)","data":null,"message":"x"}"#
      ))
      await #expect(throws: testCase.2) {
        try await repository.transferFestival(Self.request)
      }
    }
    let offline = makeRepository(client: RecordingClient(error: .transport(.notConnected)))
    await #expect(throws: BearerError.offline) {
      try await offline.transferFestival(Self.request)
    }
  }

  @Test("로그인하지 않았으면 축제 이동 요청을 보내지 않는다")
  func transferNeedsSession() async throws {
    let client = RecordingClient(json: Self.transferJSON)
    let repository = makeRepository(
      client: client,
      auth: StubAuthService(loggedIn: false)
    )

    await #expect(throws: BearerError.notAuthenticated) {
      try await repository.transferFestival(Self.request)
    }
    #expect(await client.sent.isEmpty)
  }

  @Test("UseCase는 이동마다 새 transfer- 멱등키를 만들고 다시 보낼 때는 같은 요청을 그대로 넘긴다")
  func transferRequestKey() async throws {
    let client = RecordingClient(json: Self.transferJSON)
    let repository = makeRepository(client: client)
    let useCase = withDependencies {
      $0.uuid = .incrementing
      $0.bearerRepository = repository
    } operation: {
      BearerUseCaseImpl()
    }
    let first = useCase.makeFestivalTransferRequest(
      flagID: "flg_123",
      fromFestivalID: "fst_old",
      toFestivalID: "fst_new"
    )
    let second = useCase.makeFestivalTransferRequest(
      flagID: "flg_123",
      fromFestivalID: "fst_old",
      toFestivalID: "fst_new"
    )

    #expect(first.idempotencyKey.hasPrefix("transfer-"))
    #expect(first.idempotencyKey == first.idempotencyKey.lowercased())
    #expect(first.idempotencyKey != second.idempotencyKey)
    #expect(first.flagID == "flg_123")
    #expect(first.fromFestivalID == "fst_old")
    #expect(first.toFestivalID == "fst_new")

    _ = try await useCase.transferFestival(first)
    _ = try await useCase.transferFestival(first)
    let keys = await client.sent.map { $0.headers["Idempotency-Key"] }
    #expect(keys == [first.idempotencyKey, first.idempotencyKey])
  }

  private func makeRepository(
    client: RecordingClient,
    auth: StubAuthService = StubAuthService()
  ) -> BearerRepositoryImpl {
    return withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: {
      BearerRepositoryImpl(baseURL: baseURL)
    }
  }

  static let request = BearerFestivalTransferRequest(
    flagID: "flg_123",
    fromFestivalID: "fst_old",
    toFestivalID: "fst_new",
    idempotencyKey: "transfer-1"
  )

  static let transferJSON = #"""
  {"code":"SUCCESS","message":"OK","data":{"flagId":"flg_123","previousFestivalId":"fst_old","festivalId":"fst_new","flag":{"id":"flg_123","name":"푸른 깃발","thumbUrl":null,"photoUrl":null,"tags":["sing"],"bio":"같이 달려요","followerCount":12,"planVisible":true,"plan":[],"homeZoneId":null}}}
  """#
}
