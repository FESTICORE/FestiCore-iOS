import Dependencies
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

@Suite("크루 생성 저장소 통신")
struct FestivalCrewRepositoryTests {
  private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  @Test func createsCrewWithSessionAndMapsResponse() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"flg_1","festivalId":"fst_1","name":"친구들","ownerId":"usr_1","members":[{"userId":"usr_1","nickname":"로이","joinedAt":"2026-10-21T01:00:00.000Z"}],"inviteCode":"K7P2QX","inviteExpiresAt":"2026-10-23T01:00:00.000Z"}}"#)
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )

    let crew = try await repository.create(
      festivalID: "fst_1",
      name: "친구들",
      nickname: nil
    )
    #expect(crew.id == "flg_1")
    #expect(crew.members.map(\.nickname) == ["로이"])
    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/crews")
    #expect(sent.method == "POST")
    #expect(sent.authorization == .sessionBound(sessionID))
    let data = try #require(sent.body)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(body == ["festivalId": "fst_1", "name": "친구들"])
  }

  @Test func refusesRequestWithoutSession() async {
    let client = CrewRecordingClient(json: "")
    let repository = makeRepository(
      client: client,
      sessionID: nil
    )
    await #expect(throws: FestivalCrewError.unauthenticated) {
      try await repository.create(
        festivalID: "fst_1",
        name: "친구들",
        nickname: nil
      )
    }
    #expect(await client.sent == nil)
  }

  @Test(arguments: [
    (409, "CREW_ALREADY_IN", FestivalCrewError.alreadyInCrew),
    (410, "FESTIVAL_ENDED", FestivalCrewError.festivalEnded),
    (403, "TERMS_REQUIRED", FestivalCrewError.termsRequired)
  ])
  func mapsBackendErrors(
    status: Int,
    code: String,
    expected: FestivalCrewError
  ) async {
    let client = CrewRecordingClient(error: .response(.init(
      httpStatus: status,
      code: code
    )))
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )
    await #expect(throws: expected) {
      try await repository.create(
        festivalID: "fst_1",
        name: "친구들",
        nickname: nil
      )
    }
  }

  @Test func gatherUsesSessionAndOfficialZone() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"zoneId":"zone_a"}}"#)
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )
    try await repository.gather(
      crewID: "crew_a",
      zoneID: "zone_a"
    )
    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/crews/crew_a/gather")
    #expect(sent.method == "POST")
    #expect(sent.authorization == .sessionBound(sessionID))
    let body = try #require(sent.body)
    #expect(try JSONSerialization.jsonObject(with: body) as? [String: String] == ["zoneId": "zone_a"])
  }

  @Test(arguments: [
    (403, FestivalCrewError.forbidden),
    (410, FestivalCrewError.festivalEnded),
    (429, FestivalCrewError.cooldown)
  ])
  func gatherMapsRejection(
    status: Int,
    expected: FestivalCrewError
  ) async {
    let client = CrewRecordingClient(error: .response(.init(
      httpStatus: status,
      code: "REJECTED"
    )))
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )
    await #expect(throws: expected) {
      try await repository.gather(
        crewID: "crew_a",
        zoneID: "zone_a"
      )
    }
  }

  @Test func detailMapsLiveMembersAndArchive() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"crw_1","festivalId":"fst_1","name":"펜타 크루","ownerId":"usr_1","members":[{"userId":"usr_1","nickname":"민지","joinedAt":"2026-10-21T01:00:00.000Z"}],"inviteCode":"K7P2QX","inviteExpiresAt":"2026-10-23T01:00:00.000Z","archivedAt":null,"live":{"id":"crw_1","name":"펜타 크루","ownerId":"usr_1","members":[{"userId":"usr_1","nickname":"민지","zoneId":"zone_a","state":"here","updatedAt":"2026-10-21T01:02:00.000Z"}],"gatherRequest":{"zoneId":"zone_a","byUserId":"usr_1","at":"2026-10-21T01:03:00.000Z"},"gatherAvailableAt":"2026-10-21T01:13:00.000Z"}}}"#)
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )

    let crew = try await repository.detail(crewID: "crw_1")

    #expect(crew.live?.members.first?.state == "here")
    #expect(crew.live?.members.first?.zoneID == "zone_a")
    #expect(crew.live?.gatherRequest?.byUserID == "usr_1")
    #expect(crew.live?.gatherAvailableAt != nil)
    #expect(crew.archivedAt == nil)
    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/crews/crw_1")
    #expect(sent.method == "GET")
    #expect(sent.authorization == .sessionBound(sessionID))
  }

  @Test func updateStatusSendsStateWithIdempotencyKey() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"userId":"usr_1","zoneId":"zone_a","state":"eating","updatedAt":"2026-10-21T01:00:00.000Z"}}"#)
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )

    try await repository.updateStatus(
      crewID: "crw_1",
      state: .eating,
      zoneID: "zone_a"
    )

    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/crews/crw_1/status")
    #expect(sent.method == "POST")
    #expect(sent.idempotencyKey?.isEmpty == false)
    let data = try #require(sent.body)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(body["state"] == "eating")
    #expect(body["zoneId"] == "zone_a")
    #expect(body["clientAt"] != nil)
  }

  @Test func invitePreviewIsPublicAndMapsInviter() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"crewName":"펜타 크루","festivalId":"fst_1","festivalName":"펜타포트 락 페스티벌 2026","ownerNickname":"민지","memberCount":4,"expiresAt":"2026-08-08T14:59:00.000Z"}}"#)
    let repository = makeRepository(
      client: client,
      sessionID: nil
    )

    let invite = try await repository.invite(code: "K7P2QX")

    #expect(invite.crewName == "펜타 크루")
    #expect(invite.inviterNickname == "민지")
    #expect(invite.memberCount == 4)
    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/crews/invite/K7P2QX")
    #expect(sent.authorization == FestiCoreAuthorization.none)
  }

  @Test func joinSendsInviteCode() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"crw_1","festivalId":"fst_1","name":"펜타 크루","ownerId":"usr_1","members":[],"inviteCode":null,"inviteExpiresAt":null,"archivedAt":null}}"#)
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )

    let crew = try await repository.join(inviteCode: "K7P2QX")

    #expect(crew.id == "crw_1")
    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/crews/join")
    #expect(sent.method == "POST")
    let data = try #require(sent.body)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(body == ["inviteCode": "K7P2QX"])
  }

  @Test func leaderActionsUseCrewPaths() async throws {
    let rotate = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"inviteCode":"ABCDEF","inviteExpiresAt":"2026-10-23T01:00:00.000Z"}}"#)
    let code = try await makeRepository(
      client: rotate,
      sessionID: sessionID
    ).rotateInvite(crewID: "crw_1")
    #expect(code.code == "ABCDEF")
    #expect(await rotate.sent?.path == "api/v1/crews/crw_1/invite/rotate")

    let remove = CrewRecordingClient(json: "{}")
    try await makeRepository(
      client: remove,
      sessionID: sessionID
    ).removeMember(
      crewID: "crw_1",
      userID: "usr_2"
    )
    #expect(await remove.sent?.path == "api/v1/crews/crw_1/members/usr_2")
    #expect(await remove.sent?.method == "DELETE")

    let dissolve = CrewRecordingClient(json: "{}")
    try await makeRepository(
      client: dissolve,
      sessionID: sessionID
    ).dissolve(crewID: "crw_1")
    #expect(await dissolve.sent?.path == "api/v1/crews/crw_1")
    #expect(await dissolve.sent?.method == "DELETE")
  }

  @Test(arguments: [
    (404, "NOT_FOUND", FestivalCrewError.notFound),
    (409, "CREW_FULL", FestivalCrewError.full),
    (409, "CREW_ALREADY_IN", FestivalCrewError.alreadyInCrew),
    (410, "INVITE_EXPIRED", FestivalCrewError.festivalEnded)
  ])
  func joinMapsRejection(
    status: Int,
    code: String,
    expected: FestivalCrewError
  ) async {
    let client = CrewRecordingClient(error: .response(.init(
      httpStatus: status,
      code: code
    )))
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )
    await #expect(throws: expected) {
      try await repository.join(inviteCode: "K7P2QX")
    }
  }

  @Test func detailMapsGatherResponsesAndKeepsOldPayload() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"crw_1","festivalId":"fst_1","name":"펜타 크루","ownerId":"usr_1","members":[],"inviteCode":null,"inviteExpiresAt":null,"archivedAt":null,"live":{"id":"crw_1","name":"펜타 크루","ownerId":"usr_1","members":[],"gatherRequest":{"id":"gth_1","zoneId":"zone_a","byUserId":"usr_1","at":"2026-10-21T01:03:00.000Z","expiresAt":"2026-10-21T01:13:00.000Z","responses":[{"userId":"usr_2","nickname":"준호","response":"going","respondedAt":"2026-10-21T01:04:00.000Z"},{"userId":"usr_3","nickname":"한솔","response":"later","respondedAt":"2026-10-21T01:05:00.000Z"}],"responseSummary":{"going":1,"ack":2}},"gatherAvailableAt":null}}}"#)
    let crew = try await makeRepository(
      client: client,
      sessionID: sessionID
    ).detail(crewID: "crw_1")
    let gather = try #require(crew.live?.gatherRequest)
    #expect(gather.id == "gth_1")
    #expect(gather.expiresAt != nil)
    // 모르는 응답 값(later)은 그 줄만 버린다.
    #expect(gather.responses.map(\.userID) == ["usr_2"])
    #expect(gather.responses.first?.response == .going)
    #expect(gather.summary == .init(
      going: 1,
      ack: 2
    ))

    // 새 필드가 없던 이전 응답도 그대로 읽는다.
    let old = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"crw_1","festivalId":"fst_1","name":"펜타 크루","ownerId":"usr_1","members":[],"inviteCode":null,"inviteExpiresAt":null,"archivedAt":null,"live":{"id":"crw_1","name":"펜타 크루","ownerId":"usr_1","members":[],"gatherRequest":{"zoneId":"zone_a","byUserId":"usr_1","at":"2026-10-21T01:03:00.000Z"}}}}"#)
    let oldGather = try #require(try await makeRepository(
      client: old,
      sessionID: sessionID
    ).detail(crewID: "crw_1").live?.gatherRequest)
    #expect(oldGather.id == nil)
    #expect(oldGather.expiresAt == nil)
    #expect(oldGather.responses.isEmpty)
    #expect(oldGather.summary == .init(
      going: 0,
      ack: 0
    ))
  }

  @Test func respondToGatherSendsResponseAndMapsReply() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"gatherId":"gth_1","userId":"usr_2","nickname":"준호","response":"ack","respondedAt":"2026-10-21T01:04:00.000Z"}}"#)
    let reply = try await makeRepository(
      client: client,
      sessionID: sessionID
    ).respondToGather(
      crewID: "crw_1",
      gatherID: "gth_1",
      response: .ack
    )
    #expect(reply.gatherID == "gth_1")
    #expect(reply.response == .ack)
    let sent = try #require(await client.sent)
    #expect(sent.path == "api/v1/crews/crw_1/gather/gth_1/response")
    #expect(sent.method == "POST")
    #expect(sent.authorization == .sessionBound(sessionID))
    let body = try #require(sent.body)
    #expect(try JSONSerialization.jsonObject(with: body) as? [String: String] == ["response": "ack"])
  }

  @Test(arguments: [
    (409, "GATHER_EXPIRED", FestivalCrewError.gatherExpired),
    (403, "GATHER_SENDER", FestivalCrewError.forbidden),
    (403, "CREW_NOT_MEMBER", FestivalCrewError.forbidden),
    (404, "NOT_FOUND", FestivalCrewError.notFound),
    (410, "CREW_ARCHIVED", FestivalCrewError.festivalEnded)
  ])
  func respondToGatherMapsRejection(
    status: Int,
    code: String,
    expected: FestivalCrewError
  ) async {
    let client = CrewRecordingClient(error: .response(.init(
      httpStatus: status,
      code: code
    )))
    let repository = makeRepository(
      client: client,
      sessionID: sessionID
    )
    await #expect(throws: expected) {
      try await repository.respondToGather(
        crewID: "crw_1",
        gatherID: "gth_1",
        response: .going
      )
    }
  }

  @Test func invitePreviewMapsMemberPreview() async throws {
    let client = CrewRecordingClient(json: #"{"code":"SUCCESS","message":"OK","data":{"crewName":"락린이들","festivalId":"fst_1","festivalName":"원더리벳 2026","ownerNickname":"민지","memberCount":4,"expiresAt":"2026-08-08T14:59:00.000Z","memberPreview":[{"nickname":"민지","avatarUrl":"https://cdn.festicore.test/a.png"},{"nickname":"로이","avatarUrl":null}]}}"#)
    let invite = try await makeRepository(
      client: client,
      sessionID: nil
    ).invite(code: "K7P2QX")
    #expect(invite.memberPreview == [
      .init(
        nickname: "민지",
        avatarURL: URL(string: "https://cdn.festicore.test/a.png")
      ),
      .init(
        nickname: "로이",
        avatarURL: nil
      ),
    ])
    #expect(invite.memberCount == 4)
  }

  @Test func leaveDeletesMyMembership() async throws {
    let client = CrewRecordingClient(json: "{}")
    try await makeRepository(
      client: client,
      sessionID: sessionID,
      userID: "usr_me"
    ).leave(crewID: "crw_1")
    #expect(await client.sent?.path == "api/v1/crews/crw_1/members/usr_me")
    #expect(await client.sent?.method == "DELETE")
  }

  @Test func leaveMapsOwnerRejectionAndMissingUser() async {
    let owner = CrewRecordingClient(error: .response(.init(
      httpStatus: 409,
      code: "OWNER_CANNOT_LEAVE"
    )))
    await #expect(throws: FestivalCrewError.forbidden) {
      try await makeRepository(
        client: owner,
        sessionID: sessionID,
        userID: "usr_me"
      ).leave(crewID: "crw_1")
    }
    let noUser = CrewRecordingClient(json: "{}")
    await #expect(throws: FestivalCrewError.unauthenticated) {
      try await makeRepository(
        client: noUser,
        sessionID: sessionID
      ).leave(crewID: "crw_1")
    }
    #expect(await noUser.sent == nil)
  }

  private func makeRepository(
    client: CrewRecordingClient,
    sessionID: UUID?,
    userID: String? = nil
  ) -> FestivalCrewRepositoryImpl {
    return withDependencies {
      $0.networkClient = client
      $0.authService = CrewAuthService(
        sessionID: sessionID,
        userID: userID
      )
      $0.uuid = .incrementing
    } operation: {
      FestivalCrewRepositoryImpl()
    }
  }
}

private actor CrewRecordingClient: FestiCoreNetworkClient {
  struct Sent: Sendable {
    let path: String
    let method: String
    let authorization: FestiCoreAuthorization
    let body: Data?
    let idempotencyKey: String?
  }

  private let result: Result<FestiCoreHTTPResponse, FestiCoreNetworkError>
  private(set) var sent: Sent?

  init(json: String) {
    result = .success(FestiCoreHTTPResponse(
      statusCode: 201,
      data: Data(json.utf8)
    ))
  }

  init(error: FestiCoreNetworkError) { result = .failure(error) }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let response = try record(request)
    do { return try JSONDecoder().decode(
      type,
      from: response.data
    ) } catch {
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
    sent = Sent(
      path: request.path,
      method: request.method.rawValue,
      authorization: request.authorization,
      body: try? request.asURLRequest(baseURL: URL(string: "https://festicore.test")!).httpBody,
      idempotencyKey: request.headers["Idempotency-Key"]
    )
    return try result.get()
  }
}

private struct CrewAuthService: AuthService {
  let sessionIDValue: UUID?
  let userIDValue: String?
  init(
    sessionID: UUID?,
    userID: String? = nil
  ) {
    sessionIDValue = sessionID
    userIDValue = userID
  }

  var isLoggedIn: Bool { get async { return sessionIDValue != nil } }
  var refreshToken: String? { get async { return nil } }
  var currentUserID: String? { get async { return userIDValue } }
  var sessionID: UUID { get async { return sessionIDValue ?? UUID() } }
  var authenticatedSessionID: UUID? { get async { return sessionIDValue } }
  var hasPendingLocalClear: Bool { get async { return false } }
  var hasUnconfirmedRevocation: Bool { get async { return false } }
  var hasPendingSignOutCleanup: Bool { get async { return false } }
  var hasPendingWithdrawalAuthorizationCleanup: Bool { get async { return false } }
  var hasPendingWithdrawalCleanup: Bool { get async { return false } }
  func stageSession(
    accessToken: String,
    refreshToken: String
  ) async -> UUID { return UUID() }
  func commitSession(_ id: UUID) async -> Bool { return false }
  func discardSession(_ id: UUID) async -> Bool { return false }
  func signOut(ifSession id: UUID) async -> Bool { return false }
  func rememberUserID(_ userID: String) async {}
  func signOut() async -> Bool { return false }
  func signOut(ifSessionIDMatches sessionID: UUID) async -> Bool { return false }
  func prepareRevocation(
    _ kind: AuthRevocationKind,
    ifSessionIDMatches sessionID: UUID
  ) async -> Bool { return false }
  func finishRevocationRequest() async {}
  func confirmSignOut() async -> Bool { return false }
  func confirmWithdrawalAuthorizationRejected() async -> Bool { return false }
  func retryUnconfirmedLocalCleanup() async -> Bool { return false }
  func completeWithdrawal() async -> Bool { return false }
}
