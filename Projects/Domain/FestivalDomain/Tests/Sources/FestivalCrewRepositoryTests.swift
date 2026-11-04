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
    let repository = makeRepository(client: client, sessionID: sessionID)

    let crew = try await repository.create(festivalID: "fst_1", name: "친구들", nickname: nil)
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
    let repository = makeRepository(client: client, sessionID: nil)
    await #expect(throws: FestivalCrewError.unauthenticated) {
      try await repository.create(festivalID: "fst_1", name: "친구들", nickname: nil)
    }
    #expect(await client.sent == nil)
  }

  @Test(arguments: [
    (409, "CREW_ALREADY_IN", FestivalCrewError.alreadyInCrew),
    (410, "FESTIVAL_ENDED", FestivalCrewError.festivalEnded),
    (403, "TERMS_REQUIRED", FestivalCrewError.termsRequired)
  ])
  func mapsBackendErrors(status: Int, code: String, expected: FestivalCrewError) async {
    let client = CrewRecordingClient(error: .response(.init(httpStatus: status, code: code)))
    let repository = makeRepository(client: client, sessionID: sessionID)
    await #expect(throws: expected) {
      try await repository.create(festivalID: "fst_1", name: "친구들", nickname: nil)
    }
  }

  private func makeRepository(client: CrewRecordingClient, sessionID: UUID?) -> FestivalCrewRepositoryImpl {
    return withDependencies {
      $0.networkClient = client
      $0.authService = CrewAuthService(sessionID: sessionID)
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
  }

  private let result: Result<FestiCoreHTTPResponse, FestiCoreNetworkError>
  private(set) var sent: Sent?

  init(json: String) {
    result = .success(FestiCoreHTTPResponse(statusCode: 201, data: Data(json.utf8)))
  }

  init(error: FestiCoreNetworkError) { result = .failure(error) }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    let response = try record(request)
    do { return try JSONDecoder().decode(type, from: response.data) } catch {
      throw .decoding(.failed(error))
    }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    return try await send(request, as: R.Response.self)
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
      path: request.path, method: request.method.rawValue, authorization: request.authorization,
      body: try? request.asURLRequest(baseURL: URL(string: "https://festicore.test")!).httpBody
    )
    return try result.get()
  }
}

private struct CrewAuthService: AuthService {
  let sessionIDValue: UUID?
  init(sessionID: UUID?) { sessionIDValue = sessionID }

  var isLoggedIn: Bool { get async { return sessionIDValue != nil } }
  var refreshToken: String? { get async { return nil } }
  var currentUserID: String? { get async { return nil } }
  var sessionID: UUID { get async { return sessionIDValue ?? UUID() } }
  var authenticatedSessionID: UUID? { get async { return sessionIDValue } }
  var hasPendingLocalClear: Bool { get async { return false } }
  var hasUnconfirmedRevocation: Bool { get async { return false } }
  var hasPendingSignOutCleanup: Bool { get async { return false } }
  var hasPendingWithdrawalAuthorizationCleanup: Bool { get async { return false } }
  var hasPendingWithdrawalCleanup: Bool { get async { return false } }
  func stageSession(accessToken: String, refreshToken: String) async -> UUID { return UUID() }
  func commitSession(_ id: UUID) async -> Bool { return false }
  func discardSession(_ id: UUID) async -> Bool { return false }
  func signOut(ifSession id: UUID) async -> Bool { return false }
  func rememberUserID(_ userID: String) async {}
  func signOut() async -> Bool { return false }
  func signOut(ifSessionIDMatches sessionID: UUID) async -> Bool { return false }
  func prepareRevocation(_ kind: AuthRevocationKind, ifSessionIDMatches sessionID: UUID) async -> Bool { return false }
  func finishRevocationRequest() async {}
  func confirmSignOut() async -> Bool { return false }
  func confirmWithdrawalAuthorizationRejected() async -> Bool { return false }
  func retryUnconfirmedLocalCleanup() async -> Bool { return false }
  func completeWithdrawal() async -> Bool { return false }
}
