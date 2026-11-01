import FestiCoreDeviceInterface
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing
@testable import FestiCoreFestivalCatalog

@Suite("축제 라이브 보드 통신")
struct FestivalLiveBoardTests {
  @Test("로그아웃 상태에서는 인증과 조건부 캐시 없이 설치 ID로 요청한다")
  func loggedOutRequestIsAnonymous() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"""
        {"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test",
        "serverAt":"2026-10-31T00:30:00Z","activeFlags":[],"me":null}}
        """#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#
    ])
    let auth = LiveBoardStubAuth()
    await auth.signOut()
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: auth, device: LiveBoardStubDevice(), baseURL: nil
    )

    _ = try await service.refresh(for: "fst_test")

    let requests = await client.liveRequests
    #expect(requests.count == 1)
    #expect(requests[0].authorization == .none)
    #expect(requests[0].deviceID == "00000000-0000-4000-8000-000000000001")
    #expect(requests[0].etag == nil)
  }

  @Test("로그인 세션에 사용자 ID가 없어도 인증 요청을 유지한다")
  func authenticatedSessionWithoutUserID() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"""
        {"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test",
        "serverAt":"2026-10-31T00:30:00Z","activeFlags":[],"me":null}}
        """#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#
    ])
    let auth = LiveBoardStubAuth()
    await auth.clearUserIDKeepingSession()
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: auth, device: LiveBoardStubDevice(), baseURL: nil
    )

    _ = try await service.refresh(for: "fst_test")

    let requests = await client.liveRequests
    #expect(requests.count == 1)
    #expect(requests[0].authorization == .automatic)
    #expect(requests[0].deviceID == "00000000-0000-4000-8000-000000000001")
  }

  @Test("토큰 갱신 401은 익명 재요청 없이 호출자에게 전달한다")
  func refreshFailurePropagates() async {
    let client = LiveBoardStubClient(
      responses: [:],
      liveErrors: [0: .transport(.unknown(ResponseError(httpStatus: 401, code: "REFRESH_EXPIRED")))]
    )
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil
    )

    do {
      _ = try await service.refresh(for: "fst_test")
      Issue.record("토큰 갱신 실패가 전달되어야 한다")
    } catch FestiCoreNetworkError.transport(.unknown(let underlying)) {
      #expect((underlying as? ResponseError)?.code == "REFRESH_EXPIRED")
    } catch {
      Issue.record("토큰 갱신 실패의 원인이 유지되어야 한다")
    }
    #expect(await client.liveRequests.map(\.authorization) == [.automatic])
  }

  @Test("서버 401 응답은 익명 재요청 없이 오류로 처리한다")
  func unauthorizedResponseDoesNotRetry() async {
    let client = LiveBoardStubClient(
      responses: [:], liveResponses: [.init(statusCode: 401, data: Data())]
    )
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil
    )

    do {
      _ = try await service.refresh(for: "fst_test")
      Issue.record("서버 401이 전달되어야 한다")
    } catch FestiCoreNetworkError.response(let error) {
      #expect(error.httpStatus == 401)
    } catch {
      Issue.record("서버 401의 상태 코드가 유지되어야 한다")
    }
    #expect(await client.liveRequests.map(\.authorization) == [.automatic])
  }

  @Test("서버 401의 코드와 메시지를 보존한다")
  func unauthorizedResponsePreservesServerError() async {
    let body = #"{"code":"ACCESS_EXPIRED","message":"로그인이 만료되었습니다"}"#
    let client = LiveBoardStubClient(
      responses: [:], liveResponses: [.init(statusCode: 401, data: Data(body.utf8))]
    )
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil
    )

    do {
      _ = try await service.refresh(for: "fst_test")
      Issue.record("서버 401이 전달되어야 한다")
    } catch FestiCoreNetworkError.response(let error) {
      #expect(error.httpStatus == 401)
      #expect(error.code == "ACCESS_EXPIRED")
      #expect(error.message == "로그인이 만료되었습니다")
    } catch {
      Issue.record("서버 401 응답 정보가 유지되어야 한다")
    }
    #expect(await client.liveRequests.map(\.authorization) == [.automatic])
  }

  @Test("미발행 축제 코드만 공개 전 오류로 구분한다")
  func unpublishedFestivalCode() async {
    let client = LiveBoardStubClient(responses: [:], liveResponses: [
      .init(statusCode: 404, data: Data(#"{"code":"FESTIVAL_NOT_FOUND"}"#.utf8)),
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil
    )

    await #expect(throws: FestivalLiveBoardError.festivalNotFound) {
      try await service.refresh(for: "fst_test")
    }
    let sentDeviceID = await client.liveDeviceID
    #expect(sentDeviceID == "00000000-0000-4000-8000-000000000001")
  }

  @Test("다른 404 코드는 기존 응답 오류로 유지한다")
  func unrelatedNotFoundCode() async {
    let client = LiveBoardStubClient(responses: [:], liveResponses: [
      .init(statusCode: 404, data: Data(#"{"code":"FLAG_NOT_FOUND"}"#.utf8)),
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil
    )

    await #expect(throws: FestivalLiveBoardError.invalidResponse) {
      try await service.refresh(for: "fst_test")
    }
  }

  @Test("등록 토큰 없이 설치 ID로 라이브 상태와 공개 프로필을 조회한다")
  func mapsLiveBoard() async throws {
    #expect(try await LiveBoardStubDevice().authorization()?.deviceID == nil)
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
    #expect(flagsCachePolicy == .reloadIgnoringLocalCacheData)
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

  @Test("디렉토리는 공개 목록 순서에 라이브 상태·팔로워 수·기본 구역을 합친다")
  func mapsDirectoryFlags() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-20T09:00:00Z","activeFlags":[{"flagId":"flg_b","status":"resting","zoneId":"zone_b","activity":"calm","updatedAt":"2026-10-20T08:59:00Z"}],"me":null}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"flg_a","name":"첫 깃발","tags":["slam"],"followerCount":1284,"homeZoneId":"zone_a"},{"id":"flg_b","name":"둘째 깃발","followerCount":null,"homeZoneId":null},{"id":"flg_a","name":"중복 깃발"}]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.directoryFlags.map(\.name) == ["첫 깃발", "둘째 깃발"])
    #expect(board.directoryFlags.map(\.status) == ["scheduled", "resting"])
    #expect(board.directoryFlags.map(\.followerCount) == [1284, nil])
    #expect(board.directoryFlags.map(\.homeZoneID) == ["zone_a", nil])
    #expect(board.directoryFlags.last?.zoneID == "zone_b")
    #expect(board.directoryFlags.last?.updatedAt == date("2026-10-20T08:59:00Z"))
    #expect(board.activeFlags.first?.followerCount == nil)
  }

  @Test("공개 프로필의 팔로워 수와 기본 구역 타입 오류는 거부한다", arguments: [
    #"{"followerCount":"많음"}"#,
    #"{"homeZoneId":7}"#,
  ])
  func rejectsMalformedDirectoryMetadata(_ fields: String) {
    let object = String(fields.dropFirst().dropLast())
    let json = #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"flg_a","name":"깃발",\#(object)}]}}"#

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(FestivalFlagsResponseDTO.self, from: Data(json.utf8))
    }
  }

  @Test("설치 ID 저장 오류를 기기 미등록으로 바꾸지 않고 전달한다")
  func installationIDFailureIsNotReportedAsUnregistered() async {
    let client = LiveBoardStubClient(responses: [:])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: FailingInstallationDevice(),
      baseURL: nil
    )

    await #expect(throws: InstallationIDFailure()) {
      try await service.refresh(for: "fst_test")
    }
    #expect(await client.liveDeviceID == nil)
  }

  @Test("잘못된 공개 프로필 타입은 라이브보드 응답 오류로 돌려준다")
  func reportsMalformedDirectoryMetadata() async {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-20T09:00:00Z","activeFlags":[],"me":null}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"flg_a","name":"깃발","followerCount":"많음"}]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil)

    await #expect(throws: FestivalLiveBoardError.invalidResponse) {
      try await service.refresh(for: "fst_test")
    }
  }

  @Test("라이브 목록이 상한 50개면 빠진 깃발의 상태를 예정으로 단정하지 않는다")
  func directoryStatusIsUnknownAtLiveLimit() async throws {
    let active = (0..<50).map {
      #"{"flagId":"flg_live\#($0)","status":"active","zoneId":null,"activity":null,"updatedAt":"2026-10-20T09:00:00Z"}"#
    }.joined(separator: ",")
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-20T09:00:00Z","activeFlags":["# + active + #"],"me":null}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"flg_live0","name":"라이브"},{"id":"flg_quiet","name":"조용한 깃발"}]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      auth: LiveBoardStubAuth(),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.directoryFlags.map(\.status) == ["active", "unknown"])
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
    let clock = SequenceClock([Date(timeIntervalSince1970: 100), Date(timeIntervalSince1970: 400)])
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil, now: { clock.next() }
    )

    let first = try await service.refresh(for: "fst_test")
    let second = try await service.refresh(for: "fst_test")

    #expect(second.serverAt == first.serverAt)
    #expect(second.activeFlags == first.activeFlags)
    // 304도 이 기기가 라이브 상태를 확인한 것이므로 확인 시각은 새로 기록한다.
    #expect(first.receivedAt == Date(timeIntervalSince1970: 100))
    #expect(second.receivedAt == Date(timeIntervalSince1970: 400))
    #expect(await client.liveRequestCount == 2)
    #expect(await client.lastIfNoneMatch == "\"version-1\"")
  }

  @Test("확인 시각은 공개 프로필 요청 전에 라이브 응답 기준으로 기록한다")
  func recordsReceivedAtBeforeProfileRequest() async throws {
    let clock = SequenceClock([Date(timeIntervalSince1970: 100), Date(timeIntervalSince1970: 400)])
    let client = LiveBoardStubClient(
      responses: [
        "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","message":"OK","data":{"festivalId":"fst_test","serverAt":"2026-10-31T00:30:00Z","activeFlags":[],"me":null}}"#,
        "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","message":"OK","data":{"items":[]}}"#,
      ],
      onFlagsRequest: { _ = clock.next() }
    )
    let service = NetworkFestivalLiveBoardService(
      client: client, auth: LiveBoardStubAuth(), device: LiveBoardStubDevice(), baseURL: nil, now: { clock.next() }
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.receivedAt == Date(timeIntervalSince1970: 100))
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

  @Test("같은 사용자의 새 로그인 세션에도 이전 ETag와 팔로우 상태를 재사용하지 않는다")
  func clearsPersonalizedCacheOnSessionChange() async throws {
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
    await auth.setUserID("user-a")
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

private final class SequenceClock: @unchecked Sendable {
  private let lock = NSLock()
  private var dates: [Date]

  init(_ dates: [Date]) { self.dates = dates }

  func next() -> Date {
    lock.withLock { dates.count > 1 ? dates.removeFirst() : dates[0] }
  }
}

private actor LiveBoardStubAuth: AuthService {
  private var userID: String? = "user-a"
  private var loggedIn = true
  private var activeSessionID = UUID()
  var isLoggedIn: Bool { loggedIn }
  var refreshToken: String? { nil }
  var currentUserID: String? { userID }
  var sessionID: UUID { activeSessionID }
  var authenticatedSessionID: UUID? { loggedIn ? activeSessionID : nil }
  var hasPendingLocalClear: Bool { false }
  var hasUnconfirmedRevocation: Bool { false }
  var hasPendingSignOutCleanup: Bool { false }
  var hasPendingWithdrawalAuthorizationCleanup: Bool { false }
  var hasPendingWithdrawalCleanup: Bool { false }

  func setUserID(_ value: String?) {
    userID = value
    loggedIn = value != nil
    activeSessionID = UUID()
  }
  func clearUserIDKeepingSession() { userID = nil }
  func stageSession(accessToken _: String, refreshToken _: String) -> UUID { UUID() }
  func commitSession(_: UUID) -> Bool { false }
  func discardSession(_: UUID) -> Bool { false }
  func signOut(ifSession _: UUID) -> Bool { false }
  func rememberUserID(_ value: String) { userID = value }
  func signOut() -> Bool {
    activeSessionID = UUID()
    userID = nil
    loggedIn = false
    return true
  }
  func signOut(ifSessionIDMatches expected: UUID) -> Bool {
    guard activeSessionID == expected else { return false }
    return signOut()
  }
  func prepareRevocation(_: AuthRevocationKind, ifSessionIDMatches _: UUID) -> Bool { false }
  func finishRevocationRequest() {}
  func confirmSignOut() -> Bool { false }
  func confirmWithdrawalAuthorizationRejected() -> Bool { false }
  func retryUnconfirmedLocalCleanup() -> Bool { false }
  func completeWithdrawal() -> Bool { false }
}

private struct LiveBoardStubDevice: DeviceRegistrationService {
  func installationDeviceID() async throws -> String { "00000000-0000-4000-8000-000000000001" }

  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    throw FestivalLiveBoardError.deviceNotRegistered
  }

  func authorization() async throws -> DeviceAuthorization? {
    nil
  }
}

private struct InstallationIDFailure: Error, Equatable {}

private struct FailingInstallationDevice: DeviceRegistrationService {
  func installationDeviceID() async throws -> String { throw InstallationIDFailure() }

  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    throw InstallationIDFailure()
  }

  func authorization() async throws -> DeviceAuthorization? { nil }
}

private actor LiveBoardStubClient: FestiCoreRequestClient {
  struct LiveRequest: Sendable {
    let authorization: FestiCoreAuthorization
    let deviceID: String?
    let etag: String?
  }

  private let responses: [String: String]
  private let liveResponses: [FestiCoreHTTPResponse]
  private let liveErrors: [Int: FestiCoreNetworkError]
  private var nextLiveResponseIndex = 0
  private(set) var liveRequests: [LiveRequest] = []
  private(set) var liveDeviceID: String?
  private(set) var lastIfNoneMatch: String?
  private(set) var liveRequestCount = 0
  private(set) var liveCachePolicy: URLRequest.CachePolicy?
  private(set) var flagsCachePolicy: URLRequest.CachePolicy?
  private let onFlagsRequest: (@Sendable () -> Void)?

  init(
    responses: [String: String],
    liveResponses: [FestiCoreHTTPResponse] = [],
    liveErrors: [Int: FestiCoreNetworkError] = [:],
    onFlagsRequest: (@Sendable () -> Void)? = nil
  ) {
    self.responses = responses
    self.liveResponses = liveResponses
    self.liveErrors = liveErrors
    self.onFlagsRequest = onFlagsRequest
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
      onFlagsRequest?()
    }
    guard let value = responses[request.path] else {
      throw .request(.invalidURL)
    }
    do {
      return try JSONDecoder().decode(R.Response.self, from: Data(value.utf8))
    } catch {
      throw .decoding(.failed(error))
    }
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    guard request.path.hasSuffix("/live") else { throw .request(.invalidURL) }
    liveDeviceID = request.headers.value(for: "X-Device-Id")
    lastIfNoneMatch = request.headers.value(for: "If-None-Match")
    liveCachePolicy = request.cachePolicy
    liveRequestCount += 1
    liveRequests.append(LiveRequest(
      authorization: request.authorization,
      deviceID: request.headers.value(for: "X-Device-Id"),
      etag: request.headers.value(for: "If-None-Match")
    ))
    if let error = liveErrors[liveRequestCount - 1] { throw error }
    if nextLiveResponseIndex < liveResponses.count {
      defer { nextLiveResponseIndex += 1 }
      return liveResponses[nextLiveResponseIndex]
    }
    guard let value = responses[request.path] else { throw .request(.invalidURL) }
    return .init(statusCode: 200, data: Data(value.utf8))
  }
}
