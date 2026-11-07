import Dependencies
import FestiCoreNetworkInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

@Suite("깃발 상세 저장소 통신")
struct FestivalFlagDetailRepositoryTests {
  @Test("로그인 응답을 도메인 값으로 바꾸고 공개 상세 요청을 보낸다")
  func mapsSignedInDetail() async throws {
    let client = FlagDetailRecordingClient(json: Self.json())
    let detail = try await makeRepository(client: client).detail(flagID: "flg_1")

    #expect(detail.id == "flg_1")
    #expect(detail.name == "호락호락")
    #expect(detail.tags == ["slam", "sing"])
    #expect(detail.bio == "처음 와도 괜찮아요")
    #expect(detail.followerCount == 1_284)
    #expect(detail.isPlanVisible)
    #expect(detail.planSetIDs == ["set_a", "set_b"])
    #expect(detail.homeZoneID == "zone_home")
    #expect(detail.status == .active)
    #expect(detail.zoneID == "zone_a")
    #expect(detail.activity == .slam)
    #expect(detail.statusUpdatedAt == ISO8601DateFormatter().date(from: "2026-11-07T10:00:00Z"))
    #expect(detail.isFollowing == true)
    #expect(detail.isBearer == false)
    #expect(!detail.isHidden)
    // 상대 사진 경로는 앱 이미지 주소 해석기로 바꾼다.
    #expect(detail.photoURL?.absoluteString == "https://festicore.test/api/v1/flags/flg_1/photo")
    #expect(detail.thumbnailURL?.absoluteString == "https://cdn.festicore.test/thumb.webp")
    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/flags/flg_1")
    #expect(sent.method == "GET")
    #expect(sent.authorization == .automatic)
  }

  @Test("익명 응답은 팔로우·기수 여부를 비우고 빈 값과 모르는 원소를 견딘다")
  func mapsAnonymousDetailWithNulls() async throws {
    let json = #"{"code":"SUCCESS","message":"OK","data":{"id":"flg_1","name":"호락호락","thumbUrl":null,"photoUrl":null,"tags":["slam",3,null],"bio":null,"followerCount":0,"planVisible":false,"plan":[],"homeZoneId":null,"status":{"flagId":"flg_1","status":"scheduled","zoneId":null,"activity":"dance","updatedAt":"2026-11-07T10:00:00.000Z"},"isFollowing":null,"isBearer":null,"hidden":false}}"#
    let detail = try await makeRepository(client: FlagDetailRecordingClient(json: json)).detail(flagID: "flg_1")

    #expect(detail.isFollowing == nil)
    #expect(detail.isBearer == nil)
    #expect(detail.tags == ["slam"])
    #expect(detail.photoURL == nil)
    #expect(detail.thumbnailURL == nil)
    #expect(detail.bio == nil)
    #expect(!detail.isPlanVisible)
    #expect(detail.planSetIDs.isEmpty)
    #expect(detail.status == .scheduled)
    // 모르는 활동은 표시만 생략한다.
    #expect(detail.activity == nil)
  }

  @Test("모르는 상태, 다른 깃발 ID, 실패 코드, 필수 값 누락은 응답 오류로 막는다")
  func rejectsUnexpectedResponses() async {
    let cases = [
      Self.json(status: "dancing"),
      Self.json(id: "flg_other"),
      Self.json(code: "FAIL"),
      Self.json(statusFlagID: "flg_other"),
      Self.json().replacingOccurrences(
        of: #","hidden":false"#,
        with: ""
      ),
      Self.json().replacingOccurrences(
        of: #""planVisible":true,"#,
        with: ""
      ),
      Self.json().replacingOccurrences(
        of: #""plan":["set_a","set_b"]"#,
        with: #""plan":{"id":"set_a"}"#
      ),
      Self.json().replacingOccurrences(
        of: #""tags":["slam","sing"],"#,
        with: ""
      ),
      #"{"code":"SUCCESS","message":"OK","data":{"id":"flg_1"}}"#,
    ]
    for json in cases {
      let repository = makeRepository(client: FlagDetailRecordingClient(json: json))
      await #expect(throws: FestivalFlagDetailError.invalidResponse) {
        _ = try await repository.detail(flagID: "flg_1")
      }
    }
  }

  @Test("네트워크 오류를 상세 오류로 바꾼다")
  func mapsNetworkErrors() async {
    let cases = [
      FlagDetailErrorCase(
        network: .response(ResponseError(
          httpStatus: 404,
          code: "NOT_FOUND"
        )),
        expected: .notFound
      ),
      FlagDetailErrorCase(
        network: .response(ResponseError(httpStatus: 500)),
        expected: .unavailable
      ),
      FlagDetailErrorCase(
        network: .transport(.timedOut),
        expected: .unavailable
      ),
    ]
    for item in cases {
      let repository = makeRepository(client: FlagDetailRecordingClient(error: item.network))
      await #expect(throws: item.expected) {
        _ = try await repository.detail(flagID: "flg_1")
      }
    }
  }

  @Test("경로에 넣을 수 없는 ID는 요청하지 않는다")
  func rejectsInvalidIDWithoutRequest() async {
    let client = FlagDetailRecordingClient(json: Self.json())
    let repository = makeRepository(client: client)
    for id in ["", "flg/1", "flg 1", "../flg"] {
      await #expect(throws: FestivalFlagDetailError.notFound) {
        _ = try await repository.detail(flagID: id)
      }
    }
    #expect(await client.sent == nil)
  }

  @Test("로그인 상세의 대표 깃발 여부를 옮기고 필드가 없으면 비운다")
  func mapsPinnedFlag() async throws {
    let pinned = Self.json().replacingOccurrences(
      of: #""isBearer":false,"#,
      with: #""isBearer":false,"isPinned":true,"#
    )
    let detail = try await makeRepository(client: FlagDetailRecordingClient(json: pinned)).detail(flagID: "flg_1")
    #expect(detail.isPinned == true)

    let older = try await makeRepository(client: FlagDetailRecordingClient(json: Self.json())).detail(flagID: "flg_1")
    #expect(older.isPinned == nil)
  }

  @Test("신고는 사유를 담아 로그인 토큰으로 보낸다")
  func reportSendsReason() async throws {
    let client = FlagDetailRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"reportId":"report_1"}}"#)
    try await makeRepository(client: client).report(
      flagID: "flg_1",
      reason: .inappropriate
    )

    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/flags/flg_1/report")
    #expect(sent.method == "POST")
    #expect(sent.authorization == .automatic)
    #expect(sent.body == #"{"reason":"inappropriate"}"#)
  }

  @Test("신고 실패를 로그인·약관·중복·없는 깃발·일시 오류로 나눈다")
  func mapsReportErrors() async {
    let cases: [(FestiCoreNetworkError, FestivalFlagReportError)] = [
      (
        .response(ResponseError(httpStatus: 401)),
        .loginRequired
      ),
      (
        .response(ResponseError(
          httpStatus: 403,
          code: "TERMS_REQUIRED"
        )),
        .termsRequired
      ),
      (
        .response(ResponseError(
          httpStatus: 409,
          code: "ALREADY_REPORTED"
        )),
        .alreadyReported
      ),
      (
        .response(ResponseError(httpStatus: 404)),
        .notFound
      ),
      (
        .response(ResponseError(httpStatus: 500)),
        .unavailable
      ),
      (
        .transport(.timedOut),
        .unavailable
      ),
    ]
    for item in cases {
      let repository = makeRepository(client: FlagDetailRecordingClient(error: item.0))
      await #expect(throws: item.1) {
        try await repository.report(
          flagID: "flg_1",
          reason: .fake
        )
      }
    }
    let invalid = FlagDetailRecordingClient(json: "{}")
    await #expect(throws: FestivalFlagReportError.invalidRequest) {
      try await makeRepository(client: invalid).report(
        flagID: "flg/1",
        reason: .fake
      )
    }
    #expect(await invalid.sent == nil)
  }

  @Test("대표 깃발 지정·해제는 PUT으로 보내고 서버가 저장한 값을 돌려준다")
  func setsAndClearsPinnedFlag() async throws {
    let pinClient = FlagDetailRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"pinnedFlagId":"flg_1"}}"#)
    let pinned = try await makeRepository(client: pinClient).setPinnedFlag("flg_1")
    #expect(pinned == "flg_1")
    let pinSent = try #require(await pinClient.sent)
    #expect(pinSent.path == "api/v1/me/pinned-flag")
    #expect(pinSent.method == "PUT")
    #expect(pinSent.authorization == .automatic)
    #expect(pinSent.body == #"{"flagId":"flg_1"}"#)

    let clearClient = FlagDetailRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"pinnedFlagId":null}}"#)
    let cleared = try await makeRepository(client: clearClient).setPinnedFlag(nil)
    #expect(cleared == nil)
    #expect(try #require(await clearClient.sent).body == #"{"flagId":null}"#)
  }

  @Test("대표 깃발 응답이 요청과 다르거나 값이 빠지면 형식 오류, 팔로우하지 않은 깃발은 따로 알린다")
  func mapsPinErrors() async {
    let mismatched = FlagDetailRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"pinnedFlagId":"flg_other"}}"#)
    await #expect(throws: FestivalFlagPinError.invalidResponse) {
      _ = try await makeRepository(client: mismatched).setPinnedFlag("flg_1")
    }
    let missing = FlagDetailRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{}}"#)
    await #expect(throws: FestivalFlagPinError.invalidResponse) {
      _ = try await makeRepository(client: missing).setPinnedFlag(nil)
    }
    let cases: [(FestiCoreNetworkError, FestivalFlagPinError)] = [
      (
        .response(ResponseError(httpStatus: 401)),
        .loginRequired
      ),
      (
        .response(ResponseError(
          httpStatus: 403,
          code: "TERMS_REQUIRED"
        )),
        .termsRequired
      ),
      (
        .response(ResponseError(
          httpStatus: 409,
          code: "PIN_NOT_FOLLOWING"
        )),
        .notFollowing
      ),
      (
        .transport(.timedOut),
        .unavailable
      ),
    ]
    for item in cases {
      let repository = makeRepository(client: FlagDetailRecordingClient(error: item.0))
      await #expect(throws: item.1) {
        _ = try await repository.setPinnedFlag("flg_1")
      }
    }
  }

  @Test("유스케이스는 저장소 결과를 그대로 돌려준다")
  func useCaseDelegatesToRepository() async throws {
    let client = FlagDetailRecordingClient(json: Self.json())
    let detail = try await withDependencies {
      $0.networkClient = client
      $0.festivalCatalogService = FlagDetailCatalogService()
      $0.festivalFlagDetailRepository = FestivalFlagDetailRepositoryImpl()
    } operation: {
      try await FestivalFlagDetailUseCaseImpl().detail(flagID: "flg_1")
    }
    #expect(detail.id == "flg_1")
  }

  private func makeRepository(client: FlagDetailRecordingClient) -> FestivalFlagDetailRepositoryImpl {
    return withDependencies {
      $0.networkClient = client
      $0.festivalCatalogService = FlagDetailCatalogService()
    } operation: {
      FestivalFlagDetailRepositoryImpl()
    }
  }

  private static func json(
    code: String = "SUCCESS",
    id: String = "flg_1",
    status: String = "active",
    statusFlagID: String = "flg_1"
  ) -> String {
    return #"{"code":"\#(code)","message":"OK","data":{"id":"\#(id)","name":"호락호락","thumbUrl":"https://cdn.festicore.test/thumb.webp","photoUrl":"/api/v1/flags/flg_1/photo","tags":["slam","sing"],"bio":"처음 와도 괜찮아요","followerCount":1284,"planVisible":true,"plan":["set_a","set_b"],"homeZoneId":"zone_home","status":{"flagId":"\#(statusFlagID)","status":"\#(status)","zoneId":"zone_a","activity":"slam","updatedAt":"2026-11-07T10:00:00Z"},"isFollowing":true,"isBearer":false,"hidden":false}}"#
  }
}

private struct FlagDetailErrorCase {
  let network: FestiCoreNetworkError
  let expected: FestivalFlagDetailError
}

/// 상대 경로는 테스트 호스트에, https 절대 주소는 그대로 푼다.
private struct FlagDetailCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] { return [] }
  func refresh() async throws -> [FestivalCatalogItem] { return [] }
  func imageURL(for value: String?) -> URL? {
    guard let value else { return nil }
    if value.hasPrefix("/") { return URL(string: "https://festicore.test\(value)") }
    return URL(string: value)
  }
}

private actor FlagDetailRecordingClient: FestiCoreNetworkClient {
  struct Sent: Sendable {
    let path: String
    let method: String
    let authorization: FestiCoreAuthorization
    /// JSON으로 인코딩한 요청 본문. 없으면 nil.
    let body: String?
  }

  private let result: Result<FestiCoreHTTPResponse, FestiCoreNetworkError>
  private(set) var sent: Sent?

  init(json: String) {
    result = .success(FestiCoreHTTPResponse(
      statusCode: 200,
      data: Data(json.utf8)
    ))
  }

  init(error: FestiCoreNetworkError) { result = .failure(error) }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let response = try record(request)
    do {
      return try JSONDecoder().decode(
        type,
        from: response.data
      )
    } catch {
      throw .decoding(.failed(error))
    }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    return try await send(
      request,
      as: R.Response.self
    )
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    return try record(request)
  }

  func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.invalidURL)
  }

  func upload(_ request: some FestiCoreFileUploadRequest) async throws(FestiCoreNetworkError) {
    throw .request(.invalidURL)
  }

  private func record<R: FestiCoreDataRequest>(_ request: R) throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    sent = Sent(
      path: request.path,
      method: request.method.rawValue,
      authorization: request.authorization,
      body: request.parameters.flatMap { try? encoder.encode($0) }.map { data in
        return String(
          decoding: data,
          as: UTF8.self
        )
      }
    )
    return try result.get()
  }
}
