import FestiCoreDeviceInterface
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import FestiCoreFestivalCatalog

@Suite("축제 라이브 보드 통신")
struct FestivalLiveBoardTests {
  @Test("라이브 상태와 공개 프로필을 합쳐 크루·팔로우·활성 깃발을 반환한다")
  func mapsLiveBoard() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"""
        {"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test",
        "serverAt":"2026-10-20T09:00:00Z",
        "activeFlags":[{"flagId":"flg_a","status":"active","zoneId":"A","activity":"sing",
        "updatedAt":"2026-10-20T09:00:01.123Z"}],
        "me":{"following":["flg_a","flg_b"],"pinnedFlagId":"flg_b",
        "crew":{"id":"crw_a","name":"우리 크루","ownerId":"usr_a",
        "gatherRequest":{"zoneId":"B","byUserId":"usr_a","at":"2026-10-20T09:00:02Z"},
        "gatherAvailableAt":"2026-10-20T09:10:00.456Z",
        "members":[{"userId":"usr_a","nickname":"서원지","state":"here","zoneId":"B",
        "updatedAt":"2026-10-20T09:00:03Z"}]}}}}
        """#,
      "api/v1/festivals/fst_test/flags": #"""
        {"code":"SUCCESS","message":"OK","data":{"items":[
        {"id":"flg_a","name":"첫 깃발","thumbUrl":"/image/a","tags":["sing"]},
        {"id":"flg_b","name":"두 번째 깃발","thumbUrl":null,"tags":["slam","newbie"]}]}}
        """#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: URL(string: "https://festicore-dev.up.railway.app")
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.activeFlags.map(\.name) == ["첫 깃발"])
    #expect(board.activeFlags.first?.thumbnailURL?.absoluteString ==
      "https://festicore-dev.up.railway.app/image/a")
    #expect(board.followedFlags.map(\.name) == ["첫 깃발", "두 번째 깃발"])
    #expect(board.serverAt == date("2026-10-20T09:00:00Z"))
    #expect(board.pinnedFlagID == "flg_b")
    #expect(board.activeFlags.first?.tags == ["sing"])
    #expect(board.activeFlags.first?.updatedAt == date("2026-10-20T09:00:01.123Z"))
    #expect(board.followedFlags.last?.tags == ["slam", "newbie"])
    #expect(board.followedFlags.last?.updatedAt == nil)
    #expect(board.crew?.ownerID == "usr_a")
    #expect(board.crew?.gatherRequest?.zoneID == "B")
    #expect(board.crew?.gatherRequest?.byUserID == "usr_a")
    #expect(board.crew?.gatherRequest?.at == date("2026-10-20T09:00:02Z"))
    #expect(board.crew?.gatherAvailableAt == date("2026-10-20T09:10:00.456Z"))
    #expect(board.crew?.members.first?.nickname == "서원지")
    #expect(board.crew?.members.first?.updatedAt == date("2026-10-20T09:00:03Z"))
    let sentDeviceID = await client.liveDeviceID
    #expect(sentDeviceID == "00000000-0000-4000-8000-000000000001")
    let liveCachePolicy = await client.liveCachePolicy
    let flagsCachePolicy = await client.flagsCachePolicy
    #expect(liveCachePolicy == .reloadIgnoringLocalCacheData)
    #expect(flagsCachePolicy == nil)
  }

  @Test("선택 필드가 없는 응답과 null 집결 요청도 디코딩한다")
  func decodesLegacyAndNullFields() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-20T09:00:00Z","activeFlags":[{"flagId":"flg_a","status":"resting","updatedAt":"2026-10-20T09:00:01Z"}],"me":{"following":["flg_a"],"crew":{"id":"crw_a","name":"우리 크루","members":[],"gatherRequest":null}}}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"flg_a","name":"첫 깃발"}]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.serverAt == date("2026-10-20T09:00:00Z"))
    #expect(board.pinnedFlagID == nil)
    #expect(board.activeFlags.first?.updatedAt == date("2026-10-20T09:00:01Z"))
    #expect(board.activeFlags.first?.tags == [])
    #expect(board.crew?.ownerID == nil)
    #expect(board.crew?.gatherRequest == nil)
    #expect(board.crew?.gatherAvailableAt == nil)
  }

  @Test("선택적 크루 날짜가 잘못되면 안전하게 비운다")
  func rejectsInvalidDates() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-20T09:00:00Z","activeFlags":[{"flagId":"flg_a","status":"active","updatedAt":"2026-10-20T09:00:01Z"}],"me":{"following":[],"crew":{"id":"crw_a","name":"우리 크루","members":[{"userId":"usr_a","nickname":"서원지","state":"here","updatedAt":"invalid"}],"gatherRequest":{"zoneId":null,"byUserId":"usr_a","at":"invalid"},"gatherAvailableAt":"invalid"}}}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.serverAt != nil)
    #expect(board.activeFlags.first?.updatedAt != nil)
    #expect(board.crew?.members.first?.updatedAt == nil)
    #expect(board.crew?.gatherRequest == nil)
    #expect(board.crew?.gatherAvailableAt == nil)
  }

  @Test("로그인 응답에 크루가 null이어도 디코딩한다")
  func decodesNullCrew() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-20T09:00:00Z","activeFlags":[],"me":{"following":[],"crew":null}}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.crew == nil)
  }

  @Test("상태와 갱신 시각이 null인 크루 멤버를 매핑한다")
  func mapsNullMemberState() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-20T09:00:00Z","activeFlags":[],"me":{"following":[],"crew":{"id":"crw_a","name":"우리 크루","members":[{"userId":"usr_a","nickname":"서원지","zoneId":null,"state":null,"updatedAt":null}]}}}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.crew?.members.first?.id == "usr_a")
    #expect(board.crew?.members.first?.state == nil)
    #expect(board.crew?.members.first?.updatedAt == nil)
  }

  @Test("잘못된 태그 형식은 버리고 문자열 태그만 남긴다")
  func ignoresInvalidProfileTags() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-20T09:00:00Z","activeFlags":[],"me":{"following":["flg_number","flg_object","flg_mixed"],"crew":null}}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"flg_number","name":"숫자","tags":12},{"id":"flg_object","name":"객체","tags":{"bad":true}},{"id":"flg_mixed","name":"혼합","tags":["slam",12,{"bad":true},null,"sing"]}]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.followedFlags.map(\.name) == ["숫자", "객체", "혼합"])
    #expect(board.followedFlags.map(\.tags) == [[], [], ["slam", "sing"]])
  }

  @Test("공개 프로필의 위험한 썸네일 URL은 제외한다")
  func rejectsUnsafeProfileThumbnail() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-31T00:30:00Z","activeFlags":[{"flagId":"flg_a","status":"active","zoneId":null,"activity":null,"updatedAt":"2026-10-31T00:29:00Z"}],"me":null}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"flg_a","name":"첫 깃발","thumbUrl":"javascript:alert(1)"}]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: URL(string: "https://festicore-dev.up.railway.app")
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.activeFlags.first?.thumbnailURL == nil)
    #expect(board.serverAt != nil)
    #expect(board.activeFlags.first?.updatedAt != nil)
  }

  @Test(arguments: [
    #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","activeFlags":[],"me":null}}"#,
    #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-31T00:30:00Z","activeFlags":[{"flagId":"flg_a","status":"active","updatedAt":"invalid"}],"me":null}}"#,
  ])
  func rejectsMissingOrMalformedLiveTimestamp(_ response: String) async {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": response,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil)

    await #expect(throws: FestivalLiveBoardError.invalidResponse) {
      try await service.refresh(for: "fst_test")
    }
  }

  @Test("경로에 사용할 수 없는 축제 ID는 전송 전에 거부한다")
  func rejectsUnsafeFestivalID() async {
    let service = NetworkFestivalLiveBoardService(
      client: LiveBoardStubClient(responses: [:]),
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )
    await #expect(throws: FestivalLiveBoardError.self) {
      try await service.refresh(for: "../admin")
    }
  }

  @Test("ETag를 재전송하고 304 응답에는 이전 라이브 상태를 재사용한다")
  func reusesNotModifiedLiveBoard() async throws {
    let live = #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-31T00:30:00Z","activeFlags":[],"me":null}}"#
    let client = LiveBoardStubClient(
      responses: [
        "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#,
      ],
      liveResponses: [
        .init(statusCode: 200, data: Data(live.utf8), headers: ["ETag": "\"version-1\""]),
        .init(statusCode: 304, data: Data()),
      ]
    )
    let service = NetworkFestivalLiveBoardService(client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil)

    let first = try await service.refresh(for: "fst_test")
    let second = try await service.refresh(for: "fst_test")

    #expect(second == first)
    #expect(await client.liveRequestCount == 2)
    #expect(await client.lastIfNoneMatch == "\"version-1\"")
  }

  @Test("429 이후 Retry-After 동안 재요청하거나 개인화 캐시를 반환하지 않는다")
  func backsOffWhenRateLimited() async throws {
    let live = #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-31T00:30:00Z","activeFlags":[],"me":null}}"#
    let client = LiveBoardStubClient(
      responses: [
        "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#,
      ],
      liveResponses: [
        .init(statusCode: 200, data: Data(live.utf8)),
        .init(statusCode: 429, data: Data(), headers: ["Retry-After": "90"]),
      ]
    )
    let service = NetworkFestivalLiveBoardService(client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil)

    _ = try await service.refresh(for: "fst_test")
    await #expect(throws: FestivalLiveBoardError.rateLimited(retryAfter: 90)) {
      try await service.refresh(for: "fst_test")
    }
    await #expect(throws: FestivalLiveBoardError.self) {
      try await service.refresh(for: "fst_test")
    }
    #expect(await client.liveRequestCount == 2)
  }

  @Test("캐시 없는 429는 대기 시간을 반환한다")
  func reportsRateLimitWithoutCache() async {
    let client = LiveBoardStubClient(
      responses: [:],
      liveResponses: [.init(statusCode: 429, data: Data(), headers: ["Retry-After": "90"])]
    )
    let service = NetworkFestivalLiveBoardService(client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil)

    await #expect(throws: FestivalLiveBoardError.rateLimited(retryAfter: 90)) {
      try await service.refresh(for: "fst_test")
    }
  }

  @Test("계정 변경 후 이전 사용자의 ETag와 팔로우 상태를 재사용하지 않는다")
  func clearsPersonalizedCacheOnAccountChange() async throws {
    let firstLive = #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-31T00:30:00Z","activeFlags":[],"me":{"following":["flg_a"],"crew":null}}}"#
    let secondLive = #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-31T00:31:00Z","activeFlags":[],"me":{"following":[],"crew":null}}}"#
    let client = LiveBoardStubClient(
      responses: [
        "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#,
      ],
      liveResponses: [
        .init(statusCode: 200, data: Data(firstLive.utf8), headers: ["ETag": "\"a\""]),
        .init(statusCode: 200, data: Data(secondLive.utf8), headers: ["ETag": "\"b\""]),
      ]
    )
    let auth = LiveBoardStubAuth()
    let service = NetworkFestivalLiveBoardService(client: client, auth: auth, device: LiveBoardStubDevice(), baseURL: nil)

    let first = try await service.refresh(for: "fst_test")
    await auth.setUserID("user-b")
    let second = try await service.refresh(for: "fst_test")

    #expect(first.followedFlags.map(\.id) == ["flg_a"])
    #expect(second.followedFlags.isEmpty)
    #expect(await client.lastIfNoneMatch == nil)
  }

  private func date(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}

private actor LiveBoardStubAuth: AuthService {
  private var userID: String? = "user-a"
  var isLoggedIn: Bool { userID != nil }
  var refreshToken: String? { nil }
  var currentUserID: String? { userID }

  func setUserID(_ value: String?) { userID = value }
  func stageSession(accessToken _: String, refreshToken _: String) -> UUID { UUID() }
  func commitSession(_: UUID) -> Bool { false }
  func discardSession(_: UUID) -> Bool { false }
  func signOut(ifSession _: UUID) -> Bool { false }
  func rememberUserID(_ value: String) { userID = value }
  func signOut() { userID = nil }
}

private struct LiveBoardStubDevice: DeviceRegistrationService {
  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    throw FestivalLiveBoardError.deviceNotRegistered
  }

  func authorization() async throws -> DeviceAuthorization? {
    .init(deviceID: "00000000-0000-4000-8000-000000000001", bearerToken: "device-token")
  }
}

private actor LiveBoardStubClient: FestiCoreRequestClient {
  private let responses: [String: String]
  private let liveResponses: [FestiCoreHTTPResponse]
  private var nextLiveResponseIndex = 0
  private(set) var liveDeviceID: String?
  private(set) var lastIfNoneMatch: String?
  private(set) var liveRequestCount = 0
  private(set) var liveCachePolicy: URLRequest.CachePolicy?
  private(set) var flagsCachePolicy: URLRequest.CachePolicy?

  init(responses: [String: String], liveResponses: [FestiCoreHTTPResponse] = []) {
    self.responses = responses
    self.liveResponses = liveResponses
  }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _: R, as _: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    throw .request(.invalidURL)
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    if request.path.hasSuffix("/live") {
      liveDeviceID = request.headers.value(for: "X-Device-Id")
      liveCachePolicy = request.cachePolicy
    } else if request.path.hasSuffix("/flags") {
      flagsCachePolicy = request.cachePolicy
    }
    guard let value = responses[request.path],
          let result = try? JSONDecoder().decode(R.Response.self, from: Data(value.utf8)) else {
      throw .request(.invalidURL)
    }
    return result
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    guard request.path.hasSuffix("/live") else { throw .request(.invalidURL) }
    liveDeviceID = request.headers.value(for: "X-Device-Id")
    lastIfNoneMatch = request.headers.value(for: "If-None-Match")
    liveCachePolicy = request.cachePolicy
    liveRequestCount += 1
    if nextLiveResponseIndex < liveResponses.count {
      defer { nextLiveResponseIndex += 1 }
      return liveResponses[nextLiveResponseIndex]
    }
    guard let value = responses[request.path] else { throw .request(.invalidURL) }
    return .init(statusCode: 200, data: Data(value.utf8))
  }
}
