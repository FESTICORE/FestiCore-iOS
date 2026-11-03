//
//  BearerDomainTests.swift
//  BearerDomainTests
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Dependencies
import FestiCoreNetworkInterface
import FestiCorePackInterface
import Foundation
import ImageIO
import Testing
@testable import BearerDomain

@Suite("기수 API 도메인")
struct BearerDomainTests {
  private let baseURL = URL(string: "https://festicore.test")

  @Test("기수 상세는 세션에 묶인 GET이며 상대 사진 경로와 쉬는 중 활동을 매핑한다")
  func fetchBoard() async throws {
    let auth = StubAuthService()
    let client = RecordingClient(json: Self.boardJSON)
    let repository = makeRepository(client: client, auth: auth)

    let board = try await repository.fetchBoard(flagID: "flg_1")

    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/flags/flg_1/bearer")
    #expect(sent.method == "GET")
    #expect(sent.authorization == .sessionBound(await auth.sessionID))
    #expect(board.profile.name == "호락호락")
    #expect(board.profile.thumbnailURL?.absoluteString == "https://festicore.test/api/v1/flags/flg_1/thumbnail")
    #expect(board.profile.tags == [.slam, .newbie])
    #expect(board.status.lifecycle == .resting)
    #expect(board.status.activity == nil)
    #expect(board.status.zoneID == "zone_a")
    #expect(board.status.updatedBy == BearerCoBearer(userID: "usr_2", nickname: "민지"))
    #expect(board.followerCount == 1284)
    #expect(board.coBearers == [BearerCoBearer(userID: "usr_2", nickname: "민지")])
    #expect(board.restartUsedToday)
  }

  @Test("상태 변경 유형마다 서버 전이 규칙의 본문을 만든다")
  func statusBodies() throws {
    let clientAt = Date(timeIntervalSince1970: 1_792_540_800)
    func body(_ change: BearerStatusChange) throws -> [String: Any] {
      let data = try JSONEncoder().encode(BearerStatusRequest(change: change, idempotencyKey: "k", clientAt: clientAt).body)
      return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    let start = try body(.start(zoneID: "zone_a", activity: .sing))
    #expect(start.keys.sorted() == ["activity", "clientAt", "zoneId"])
    #expect(start["clientAt"] as? String == "2026-10-21T00:00:00.000Z")
    #expect(try body(.move(zoneID: "zone_b")).keys.sorted() == ["clientAt", "zoneId"])
    #expect(try body(.activity(.train))["activity"] as? String == "train")
    let rest = try body(.rest)
    #expect(rest["status"] as? String == "resting")
    #expect(rest["activity"] == nil)
    let end = try body(.end)
    #expect(end.keys.sorted() == ["clientAt", "status"])
    #expect(end["status"] as? String == "ended")
    let restart = try body(.restart(zoneID: "zone_a", activity: .calm))
    #expect(restart["restart"] as? Bool == true)
    #expect(restart["zoneId"] as? String == "zone_a")
    #expect(restart["activity"] as? String == "calm")
    #expect(restart["status"] == nil)
  }

  @Test("상태 전송은 멱등키 헤더를 붙이고 응답 상태를 돌려준다")
  func sendStatus() async throws {
    let client = RecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"flagId":"flg_1","status":"active","zoneId":"zone_b","activity":"sing","updatedAt":"2026-10-21T00:00:00.000Z"}}"#)
    let repository = makeRepository(client: client)
    let request = BearerStatusRequest(change: .move(zoneID: "zone_b"), idempotencyKey: "key-1", clientAt: Date())

    let status = try await repository.sendStatus(flagID: "flg_1", request: request)

    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/flags/flg_1/status")
    #expect(sent.method == "POST")
    #expect(sent.headers["Idempotency-Key"] == "key-1")
    #expect(status.lifecycle == .active)
    #expect(status.activity == .sing)
    #expect(status.updatedBy == nil)
  }

  @Test("코드 등록은 코드·기기 ID를 보내고 깃발을 돌려준다")
  func claim() async throws {
    let client = RecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"flagId":"flg_1","flag":{"id":"flg_1","name":"새 깃발 a1b2c3","thumbUrl":null,"photoUrl":null,"tags":["newbie"],"bio":null,"followerCount":0,"planVisible":true,"plan":[],"homeZoneId":null},"isNew":true,"coBearers":["usr_1"]}}"#)
    let repository = makeRepository(client: client)

    let claim = try await repository.claim(festivalID: "fst_1", code: "ABC234")

    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/bearer/claim")
    #expect(sent.headers["X-Device-Id"] == "8a5c2f8e-1d2b-4c3d-9e4f-0a1b2c3d4e5f")
    let body = try #require(sent.body.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: String] })
    #expect(body == ["festivalId": "fst_1", "code": "ABC234"])
    #expect(claim.flagID == "flg_1")
    #expect(claim.isNew)
    #expect(claim.profile.tags == [.newbie])
  }

  @Test("코드 오류는 남은 횟수와 잠금 시간을 읽는다")
  func claimFailures() async {
    let invalid = makeRepository(client: RecordingClient(status: 422, json: #"{"code":"BEARER_CODE_INVALID","data":{"remainingAttempts":2},"message":"x"}"#))
    await #expect(throws: BearerError.invalidCode(remainingAttempts: 2)) {
      try await invalid.claim(festivalID: "fst_1", code: "ABC234")
    }
    let unknown = makeRepository(client: RecordingClient(status: 422, json: #"{"code":"BEARER_CODE_INVALID","data":null,"message":"x"}"#))
    await #expect(throws: BearerError.invalidCode(remainingAttempts: nil)) {
      try await unknown.claim(festivalID: "fst_1", code: "ABC234")
    }
    let locked = makeRepository(client: RecordingClient(status: 423, json: #"{"code":"BEARER_CODE_LOCKED","data":{"retryAfter":582},"message":"x"}"#))
    await #expect(throws: BearerError.codeLocked(retryAfter: 582)) {
      try await locked.claim(festivalID: "fst_1", code: "ABC234")
    }
  }

  @Test("사진은 multipart photo 파트 하나로 올리고 주소를 매핑한다")
  func uploadPhoto() async throws {
    let auth = StubAuthService()
    let client = RecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"photoUrl":"/api/v1/flags/flg_1/photo","thumbUrl":"/api/v1/flags/flg_1/thumbnail"}}"#)
    let repository = makeRepository(client: client, auth: auth)
    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0])

    let photo = try await repository.uploadPhoto(flagID: "flg_1", jpegData: jpeg) { _ in }

    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/flags/flg_1/photo")
    #expect(sent.method == "POST")
    #expect(sent.authorization == .sessionBound(await auth.sessionID))
    #expect(sent.parts.count == 1)
    #expect(sent.parts.first?.name == "photo")
    #expect(sent.parts.first?.mimeType == "image/jpeg")
    if case let .data(data)? = sent.parts.first?.source { #expect(data == jpeg) } else { Issue.record("메모리 파트가 아니다") }
    #expect(photo.photoURL?.absoluteString == "https://festicore.test/api/v1/flags/flg_1/photo")
  }

  @Test("서버 오류 코드를 기수 오류로 나눈다", arguments: [
    (400, "VALIDATION", BearerError.invalidRequest),
    (401, "UNAUTHORIZED", .notAuthenticated),
    (403, "TERMS_REQUIRED", .termsRequired),
    (403, "FLAG_NOT_BEARER", .notBearer),
    (403, "FLAG_NOT_OWNER", .notOwner),
    (404, "ZONE_NOT_FOUND", .zoneNotFound),
    (404, "NOT_FOUND", .notFound),
    (409, "FLAG_NAME_TAKEN", .nameTaken),
    (409, "STATUS_STALE", .stale),
    (409, "FLAG_RESTART_REQUIRED", .transitionRejected),
    (409, "CO_BEARER_FULL", .coBearerFull),
    (409, "CONFLICT", .conflict),
    (413, "PAYLOAD_TOO_LARGE", .photoTooLarge),
    (415, "UNSUPPORTED_MEDIA_TYPE", .unsupportedPhoto),
    (429, "RATE_LIMITED", .rateLimited),
    (500, "INTERNAL_SERVER_ERROR", .unavailable)
  ])
  func errorMapping(status: Int, code: String, expected: BearerError) {
    #expect(BearerRepositoryImpl.map(ResponseError(httpStatus: status, code: code), detail: nil) == expected)
  }

  @Test("연결 실패는 오프라인으로, 취소는 취소로 전한다")
  func transportMapping() async {
    let offline = makeRepository(client: RecordingClient(error: .transport(.notConnected)))
    await #expect(throws: BearerError.offline) {
      try await offline.sendStatus(flagID: "flg_1", request: BearerStatusRequest(change: .rest, idempotencyKey: "k", clientAt: Date()))
    }
    #expect(BearerRepositoryImpl.map(FestiCoreNetworkError.transport(.cancelled)) is CancellationError)
  }

  @Test("로그인 세션이 없으면 요청하지 않는다")
  func notAuthenticated() async {
    let client = RecordingClient(json: Self.boardJSON)
    let repository = makeRepository(client: client, auth: StubAuthService(loggedIn: false))
    await #expect(throws: BearerError.notAuthenticated) { try await repository.fetchBoard(flagID: "flg_1") }
    #expect(await client.sent.isEmpty)
  }

  @Test("프로필 수정은 PATCH 응답 프로필을 돌려주고 공동 기수 해제는 DELETE다")
  func profileAndCoBearer() async throws {
    let client = RecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"flg_1","name":"호락호락","thumbUrl":null,"photoUrl":null,"tags":["sing"],"bio":"함께 노래해요","followerCount":3,"planVisible":false,"plan":[],"homeZoneId":"zone_a"}}"#)
    let repository = makeRepository(client: client)
    let profile = try await repository.updateProfile(
      flagID: "flg_1",
      change: BearerProfileChange(name: " 호락호락 ", bio: "  ", tags: [.sing], planVisible: false, homeZoneID: "zone_a")
    )
    let sent = try #require(await client.last)
    #expect(sent.method == "PATCH")
    let body = try #require(sent.body.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
    #expect(body["name"] as? String == "호락호락")
    #expect(body["bio"] is NSNull)
    #expect(profile.homeZoneID == "zone_a")
    #expect(!profile.planVisible)

    let removal = RecordingClient(status: 204, json: "")
    try await makeRepository(client: removal).removeCoBearer(flagID: "flg_1", userID: "usr_2")
    #expect(await removal.last?.method == "DELETE")
    #expect(await removal.last?.path == "api/v1/flags/flg_1/co-bearers/usr_2")
  }

  private func makeRepository(client: RecordingClient, auth: StubAuthService = StubAuthService()) -> BearerRepositoryImpl {
    withDependencies {
      $0.networkClient = client
      $0.authService = auth
      $0.deviceRegistrationService = StubDeviceService(deviceID: "8a5c2f8e-1d2b-4c3d-9e4f-0a1b2c3d4e5f")
    } operation: {
      BearerRepositoryImpl(baseURL: baseURL)
    }
  }

  static let boardJSON = #"""
  {"code":"SUCCESS","message":"OK","data":{
    "flag":{"id":"flg_1","name":"호락호락","thumbUrl":"/api/v1/flags/flg_1/thumbnail","photoUrl":"/api/v1/flags/flg_1/photo","tags":["slam","newbie","unknown"],"bio":null,"followerCount":1284,"planVisible":true,"plan":[],"homeZoneId":"zone_a"},
    "status":{"flagId":"flg_1","status":"resting","zoneId":"zone_a","activity":"resting","updatedAt":"2026-10-21T00:00:00.000Z","updatedBy":{"userId":"usr_2","nickname":"민지"}},
    "planVisible":true,"followerCount":1284,"coBearers":[{"userId":"usr_2","nickname":"민지"}],
    "hidden":false,"reportCount":0,"restartUsedToday":true}}
  """#
}

@Suite("기수 UseCase")
struct BearerUseCaseTests {
  @Test("상태 요청은 누른 시각과 새 멱등키로 만든다")
  func makeStatusRequest() {
    let now = Date(timeIntervalSince1970: 1_000)
    let useCase = withDependencies {
      $0.uuid = .constant(UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!)
      $0.date = .constant(now)
    } operation: { BearerUseCaseImpl() }

    let request = useCase.makeStatusRequest(.rest)

    #expect(request.change == .rest)
    #expect(request.clientAt == now)
    #expect(request.idempotencyKey == "00000000-0000-0000-0000-00000000000a")
  }

  @Test("소문자 코드는 대문자로 맞춰 저장소에 넘긴다")
  func normalizesCode() async throws {
    let received = LockIsolated<String?>(nil)
    let useCase = withDependencies {
      $0.bearerRepository = ClaimRecordingRepository(received: received)
    } operation: { BearerUseCaseImpl() }

    _ = try await useCase.claim(festivalID: "fst_1", code: "abc234")

    #expect(received.value == "ABC234")
  }

  @Test("형식이 틀린 코드는 서버에 보내지 않는다", arguments: ["ABC23", "ABC2340", "ABCI23", "AB C23"])
  func invalidCode(code: String) async {
    let useCase = withDependencies {
      $0.bearerRepository = MockBearerRepository()
    } operation: { BearerUseCaseImpl() }
    await #expect(throws: BearerError.invalidRequest) { try await useCase.claim(festivalID: "fst_1", code: code) }
  }

  @Test("받아 둔 팩에서 축제 이름과 존을 읽고 형식이 틀린 존은 건너뛴다")
  func fetchFestival() async throws {
    let pack = CachedFestivalPack(
      festivalID: "fst_1", packVersion: 1, etag: "e",
      pack: Data(#"{"id":"fst_1","name":"원더리벳 2026","zones":[{"id":"zone_a","name":"리벳 스테이지 앞 왼쪽"},{"id":"zone_b"},{"name":"이름만"}]}"#.utf8)
    )
    let useCase = withDependencies {
      $0.packSyncService = StubPackSyncService(pack: pack)
    } operation: { BearerUseCaseImpl() }

    let festival = try await useCase.fetchFestival(festivalID: "fst_1")

    #expect(festival.name == "원더리벳 2026")
    #expect(festival.zones == [BearerZone(id: "zone_a", name: "리벳 스테이지 앞 왼쪽")])
    #expect(festival.zoneName(for: "zone_a") == "리벳 스테이지 앞 왼쪽")

    let empty = try await withDependencies {
      $0.packSyncService = StubPackSyncService(pack: nil)
    } operation: { BearerUseCaseImpl() }.fetchFestival(festivalID: "fst_2")
    #expect(empty.zones.isEmpty)
  }
}

@Suite("사진 업로드 스트림")
struct BearerPhotoUploadStreamTests {
  @Test("규격을 맞춘 JPEG를 올리며 진행률을 알린 뒤 완료한다")
  func uploadsWithProgress() async throws {
    let repository = PhotoRepository()
    let useCase = withDependencies {
      $0.bearerRepository = repository
    } operation: { BearerUseCaseImpl() }
    let png = try BearerPhotoEncoderTests.png(width: 300, height: 300)

    var events: [BearerPhotoUploadEvent] = []
    for try await event in useCase.uploadPhoto(flagID: "flg_1", imageData: png) {
      events.append(event)
    }

    let photo = BearerFlagPhoto(photoURL: nil, thumbnailURL: nil)
    #expect(events == [.progress(0.4), .progress(1), .completed(photo)])
    #expect(await repository.uploaded?.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
  }

  @Test("작은 사진은 올리지 않고 스트림을 실패로 끝낸다")
  func rejectsSmallPhoto() async throws {
    let repository = PhotoRepository()
    let useCase = withDependencies {
      $0.bearerRepository = repository
    } operation: { BearerUseCaseImpl() }
    let png = try BearerPhotoEncoderTests.png(width: 200, height: 200)

    await #expect(throws: BearerError.photoTooSmall) {
      for try await _ in useCase.uploadPhoto(flagID: "flg_1", imageData: png) {}
    }
    #expect(await repository.uploaded == nil)
  }
}

private actor PhotoRepository: BearerRepositoryInterface {
  private(set) var uploaded: Data?

  func uploadPhoto(flagID: String, jpegData: Data, progress: @escaping @Sendable (Double) -> Void) async throws -> BearerFlagPhoto {
    uploaded = jpegData
    progress(0.4)
    progress(1.2)
    return BearerFlagPhoto(photoURL: nil, thumbnailURL: nil)
  }

  func claim(festivalID: String, code: String) async throws -> BearerClaim { throw BearerError.unavailable }
  func fetchBoard(flagID: String) async throws -> BearerBoard { throw BearerError.unavailable }
  func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile { throw BearerError.unavailable }
  func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus { throw BearerError.unavailable }
  func inviteCoBearer(flagID: String) async throws -> BearerInvite { throw BearerError.unavailable }
  func removeCoBearer(flagID: String, userID: String) async throws { throw BearerError.unavailable }
}

@Suite("업로드 사진 규격")
struct BearerPhotoEncoderTests {
  @Test("짧은 변이 256px보다 작으면 올리지 않는다")
  func tooSmall() throws {
    let png = try Self.png(width: 255, height: 600)
    #expect(throws: BearerError.photoTooSmall) { try BearerPhotoEncoder().encode(png) }
  }

  @Test("큰 사진은 긴 변 2048px JPEG 5MB 이하로 줄인다")
  func downscales() throws {
    let png = try Self.png(width: 3000, height: 1000)
    let jpeg = try BearerPhotoEncoder().encode(png)
    #expect(jpeg.count <= BearerPhotoEncoder.maxBytes)
    #expect(jpeg.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
    let size = try Self.pixelSize(jpeg)
    #expect(size.width == 2048)
    #expect(size.height >= 256)
  }

  @Test("이미지가 아닌 데이터는 형식 오류다")
  func notImage() {
    #expect(throws: BearerError.unsupportedPhoto) { try BearerPhotoEncoder().encode(Data("text".utf8)) }
  }

  static func png(width: Int, height: Int) throws -> Data {
    let context = try #require(CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())
    let output = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return output as Data
  }

  static func pixelSize(_ data: Data) throws -> (width: Int, height: Int) {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    return (
      try #require(properties[kCGImagePropertyPixelWidth] as? Int),
      try #require(properties[kCGImagePropertyPixelHeight] as? Int)
    )
  }
}

private struct ClaimRecordingRepository: BearerRepositoryInterface {
  let received: LockIsolated<String?>

  func claim(festivalID: String, code: String) async throws -> BearerClaim {
    received.setValue(code)
    return BearerClaim(flagID: "flg_1", profile: BearerFlagProfile(id: "flg_1", name: "깃발"), isNew: true, coBearerIDs: [])
  }

  func fetchBoard(flagID: String) async throws -> BearerBoard { throw BearerError.unavailable }
  func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile { throw BearerError.unavailable }
  func uploadPhoto(flagID: String, jpegData: Data, progress: @escaping @Sendable (Double) -> Void) async throws -> BearerFlagPhoto {
    throw BearerError.unavailable
  }
  func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus { throw BearerError.unavailable }
  func inviteCoBearer(flagID: String) async throws -> BearerInvite { throw BearerError.unavailable }
  func removeCoBearer(flagID: String, userID: String) async throws { throw BearerError.unavailable }
}
