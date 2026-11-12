//
//  BearerRegistrationTests.swift
//  BearerDomainTests
//
//  Created by FestiCore on 11/12/26.
//

import BearerDomainInterface
import Dependencies
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import BearerDomain

@Suite("코드 없는 기수 등록·기수 깃발·대표 깃발")
struct BearerRegistrationTests {
  private let baseURL = URL(string: "https://festicore.test")

  @Test("등록은 멱등키 헤더를 붙인 세션 POST이며 비운 소개·존을 보내지 않는다")
  func register() async throws {
    let auth = StubAuthService()
    let client = RecordingClient(
      status: 201,
      json: Self.registerJSON
    )
    let repository = makeRepository(
      client: client,
      auth: auth
    )
    let request = BearerRegisterRequest(
      festivalID: "fst_1",
      change: BearerProfileChange(
        name: "  호락호락 ",
        bio: "  ",
        tags: [.slam],
        planVisible: true,
        homeZoneID: nil
      ),
      idempotencyKey: "register-1"
    )

    let claim = try await repository.register(request)

    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/bearer/register")
    #expect(sent.method == "POST")
    #expect(sent.headers["Idempotency-Key"] == "register-1")
    #expect(sent.authorization == .sessionBound(await auth.sessionID))
    let body = try #require(sent.body.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
    #expect(body.keys.sorted() == ["festivalId", "name", "planVisible", "tags"])
    #expect(body["name"] as? String == "호락호락")
    #expect(claim.flagID == "flg_9")
    #expect(claim.isNew)
    #expect(claim.profile.name == "호락호락")
    #expect(claim.coBearerIDs == [])
  }

  @Test("등록 오류는 기수 한도·이름 중복·약관·존 없음으로 나눈다")
  func registerFailures() async {
    let cases: [(Int, String, BearerError)] = [
      (409, "BEARER_LIMIT", .bearerLimit),
      (409, "FLAG_NAME_TAKEN", .nameTaken),
      (409, "IDEMPOTENCY_CONFLICT", .conflict),
      (403, "TERMS_REQUIRED", .termsRequired),
      (404, "ZONE_NOT_FOUND", .zoneNotFound),
      (404, "NOT_FOUND", .notFound),
      (400, "VALIDATION", .invalidRequest),
    ]
    for testCase in cases {
      let repository = makeRepository(client: RecordingClient(
        status: testCase.0,
        json: #"{"code":"\#(testCase.1)","data":null,"message":"x"}"#
      ))
      await #expect(throws: testCase.2) {
        try await repository.register(Self.request)
      }
    }
    let offline = makeRepository(client: RecordingClient(error: .transport(.notConnected)))
    await #expect(throws: BearerError.offline) {
      try await offline.register(Self.request)
    }
  }

  @Test("로그인하지 않았으면 등록 요청을 보내지 않는다")
  func registerNeedsSession() async throws {
    let client = RecordingClient(json: Self.registerJSON)
    let repository = makeRepository(
      client: client,
      auth: StubAuthService(loggedIn: false)
    )

    await #expect(throws: BearerError.notAuthenticated) {
      try await repository.register(Self.request)
    }
    #expect(await client.sent.isEmpty)
  }

  @Test("UseCase는 등록마다 새 멱등키를 만들고 같은 요청을 그대로 넘긴다")
  func registerRequestKey() {
    let useCase = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      BearerUseCaseImpl()
    }
    let first = useCase.makeRegisterRequest(
      festivalID: "fst_1",
      change: Self.request.change
    )
    let second = useCase.makeRegisterRequest(
      festivalID: "fst_1",
      change: Self.request.change
    )

    #expect(first.idempotencyKey.hasPrefix("register-"))
    #expect(first.idempotencyKey != second.idempotencyKey)
    #expect(first.festivalID == "fst_1")
  }

  @Test("기수 깃발 목록은 페스티벌 쿼리를 붙이고 nullable 값과 모르는 상태를 매핑한다")
  func bearerFlags() async throws {
    let auth = StubAuthService()
    let client = RecordingClient(json: Self.bearerFlagsJSON)
    let repository = makeRepository(
      client: client,
      auth: auth
    )

    let flags = try await repository.fetchBearerFlags(festivalID: "fst_1")

    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/me/bearer-flags")
    #expect(sent.method == "GET")
    #expect(sent.authorization == .sessionBound(await auth.sessionID))
    #expect(flags.count == 2)
    let first = try #require(flags.first)
    #expect(first.id == "flg_1")
    #expect(first.festivalID == "fst_1")
    #expect(first.isOwner)
    #expect(first.lifecycle == .scheduled)
    #expect(first.joinedAt != nil)
    #expect(first.profile.followerCount == 128)
    #expect(first.profile.thumbnailURL?.absoluteString == "https://festicore.test/api/v1/flags/flg_1/thumbnail")
    let second = try #require(flags.last)
    #expect(!second.isOwner)
    #expect(second.isHidden)
    #expect(second.lifecycle == nil)
    #expect(second.joinedAt == nil)
    #expect(second.profile.followerCount == 0)
  }

  @Test("대표 깃발이 없으면 nil, 있으면 이름·페스티벌을 돌려준다")
  func pinnedFlag() async throws {
    let empty = RecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"pinnedFlagId":null,"flag":null}}"#)
    #expect(try await makeRepository(client: empty).fetchPinnedFlag() == nil)
    let sent = try #require(await empty.last)
    #expect(sent.path == "api/v1/me/pinned-flag")
    #expect(sent.method == "GET")

    let pinned = RecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"pinnedFlagId":"flg_1","flag":{"id":"flg_1","name":"호락호락","thumbUrl":null,"festivalId":"fst_1","isPinned":true}}}"#)
    let flag = try await makeRepository(client: pinned).fetchPinnedFlag()
    #expect(flag == BearerPinnedFlag(
      flagID: "flg_1",
      name: "호락호락",
      festivalID: "fst_1",
      thumbnailURL: nil
    ))
  }

  @Test("팔로우 목록은 세션 GET으로 받고 공개 상세 이름을 붙이며 404 깃발은 뺀다")
  func followedFlags() async throws {
    let auth = StubAuthService()
    let client = RecordingClient(routes: [
      "api/v1/me/follows": (200, #"{"code":"SUCCESS","message":"OK","data":{"items":[{"flagId":"flg_2","festivalId":"fst_1","followedAt":"2026-10-21T00:00:00.000Z"},{"flagId":"flg_gone","festivalId":"fst_1","followedAt":null},{"flagId":"flg_1","festivalId":"fst_2","followedAt":"bad"}]}}"#),
      "api/v1/flags/flg_2": (200, #"{"code":"SUCCESS","message":"OK","data":{"id":"flg_2","name":"둘째","thumbUrl":"/api/v1/flags/flg_2/thumbnail","hidden":false}}"#),
      "api/v1/flags/flg_gone": (404, #"{"code":"FLAG_NOT_FOUND","message":"없음","data":null}"#),
      "api/v1/flags/flg_1": (200, #"{"code":"SUCCESS","message":"OK","data":{"id":"flg_1","name":"첫째","thumbUrl":null}}"#)
    ])
    let repository = makeRepository(
      client: client,
      auth: auth
    )

    let flags = try await repository.fetchFollowedFlags(festivalID: nil)

    let follows = try #require(await client.sent.first)
    #expect(follows.path == "api/v1/me/follows")
    #expect(follows.method == "GET")
    #expect(follows.body == nil)
    #expect(follows.authorization == .sessionBound(await auth.sessionID))
    #expect(flags.map(\.flagID) == ["flg_2", "flg_1"])
    #expect(flags.first?.name == "둘째")
    #expect(flags.first?.festivalID == "fst_1")
    #expect(flags.first?.followedAt != nil)
    #expect(flags.first?.thumbnailURL?.absoluteString == "https://festicore.test/api/v1/flags/flg_2/thumbnail")
    #expect(flags.last?.thumbnailURL == nil)
    #expect(flags.last?.followedAt == nil)
  }

  @Test("팔로우한 깃발이 없으면 상세를 읽지 않고 빈 목록을 돌려준다")
  func emptyFollowedFlags() async throws {
    let client = RecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#)

    let flags = try await makeRepository(client: client).fetchFollowedFlags(festivalID: "fst_1")

    #expect(flags.isEmpty)
    #expect(await client.sent.count == 1)
  }

  @Test("깃발 상세가 서버 오류로 실패하면 목록 조회도 실패한다")
  func followedFlagDetailFailurePropagates() async throws {
    let client = RecordingClient(routes: [
      "api/v1/me/follows": (200, #"{"code":"SUCCESS","message":"OK","data":{"items":[{"flagId":"flg_1","festivalId":"fst_1","followedAt":null}]}}"#),
      "api/v1/flags/flg_1": (500, #"{"code":"INTERNAL","message":"오류","data":null}"#)
    ])

    await #expect(throws: BearerError.self) {
      try await makeRepository(client: client).fetchFollowedFlags(festivalID: nil)
    }
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

  static let request = BearerRegisterRequest(
    festivalID: "fst_1",
    change: BearerProfileChange(
      name: "호락호락",
      bio: nil,
      tags: [.slam],
      planVisible: true,
      homeZoneID: nil
    ),
    idempotencyKey: "register-1"
  )

  static let registerJSON = #"""
  {"code":"SUCCESS","message":"OK","data":{"flagId":"flg_9","flag":{"id":"flg_9","name":"호락호락","thumbUrl":null,"photoUrl":null,"tags":["slam"],"bio":null,"followerCount":0,"planVisible":true,"plan":[],"homeZoneId":null},"isNew":true,"coBearers":[]}}
  """#

  static let bearerFlagsJSON = #"""
  {"code":"SUCCESS","message":"OK","data":{"items":[
    {"flagId":"flg_1","festivalId":"fst_1","isOwner":true,"joinedAt":"2026-10-21T00:00:00.000Z","flag":{"id":"flg_1","name":"호락호락","thumbUrl":"/api/v1/flags/flg_1/thumbnail","photoUrl":null,"tags":["sing"],"bio":null,"followerCount":128,"planVisible":true,"plan":[],"homeZoneId":null},"status":{"flagId":"flg_1","status":"scheduled","zoneId":null,"activity":null,"updatedAt":"2026-10-21T00:00:00.000Z"},"hidden":false},
    {"flagId":"flg_2","festivalId":"fst_2","isOwner":false,"joinedAt":null,"flag":{"id":"flg_2","name":"푸른 깃발","thumbUrl":null,"photoUrl":null,"tags":null,"bio":null,"followerCount":null,"planVisible":null,"plan":null,"homeZoneId":null},"status":{"flagId":"flg_2","status":"unknown","zoneId":null,"activity":null,"updatedAt":"2026-10-21T00:00:00.000Z"},"hidden":true}
  ]}}
  """#
}
