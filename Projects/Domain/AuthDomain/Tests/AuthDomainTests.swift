//
//  AuthDomainTests.swift
//  AuthDomainTests
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import AuthDomainInterface
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import AuthDomain

@Suite("인증 API 도메인")
struct AuthDomainTests {
  @Test("Google 로그인 본문은 선택한 코드만 전달한다")
  func googleRequest() throws {
    let body = AuthCredential.google(idToken: "google-id").loginBody
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: String])
    #expect(json == ["provider": "google", "token": "google-id"])

    let withCode = AuthCredential.google(idToken: "google-id", serverAuthCode: "server-code").loginBody
    let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(withCode)) as? [String: String])
    #expect(encoded["authorizationCode"] == "server-code")
    #expect(encoded["name"] == nil)
  }

  @Test("Apple 요청은 인가 코드와 최초 이름을 전달한다")
  func appleRequest() throws {
    let body = AuthCredential.apple(
      idToken: "apple-id", authorizationCode: "apple-code", name: "원지"
    ).loginBody
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: String])
    #expect(json == [
      "provider": "apple", "token": "apple-id", "authorizationCode": "apple-code", "name": "원지"
    ])
  }

  @Test("nullable 사용자 필드와 밀리초 날짜 문자열을 손실 없이 매핑한다")
  func mapsUser() throws {
    let response = try JSONDecoder().decode(AuthLoginResponseDTO.self, from: loginBody)
    #expect(response.data.newUser)
    let user = response.data.toDomain().user
    #expect(user.email == nil)
    #expect(user.nickname == nil)
    #expect(user.termsAcceptedAt == "2026-10-29T01:02:03.123Z")
    #expect(user.profileImageURL == nil)
  }

  @Test("현재 약관 버전이 일치해야 프로필이 완료된다")
  func profileEligibility() throws {
    let response = try JSONDecoder().decode(AuthProfileResponseDTO.self, from: profileBody)
    let profile = response.data.toDomain()
    #expect(profile.user.id == "user-1")
    #expect(profile.isEligible)
    let stale = AuthProfile(user: profile.user, currentTermsVersion: "2026-11")
    #expect(!stale.isEligible)
  }

  @Test("GET me가 현재 약관 버전을 누락하면 실패한다")
  func missingTermsVersion() async {
    let auth = StubAuthService(loggedIn: true)
    let body = Data(#"{"code":"SUCCESS","message":"OK","data":{"id":"user-1","provider":"google","nicknameConfirmed":true,"termsAcceptedAt":"2026-10-30T00:00:00Z","termsVersion":"2026-10","pushOptIn":false}}"#.utf8)
    let client = StubClient(result: .success(body))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    await #expect(throws: FestiCoreNetworkError.self) { try await repository.fetchProfile() }
  }

  @Test("인증된 프로필을 GET me에서 조회한다")
  func fetchProfile() async throws {
    let client = StubClient(result: .success(profileBody))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = StubAuthService(loggedIn: true)
    } operation: { AuthRepositoryImpl() }
    let profile = try await repository.fetchProfile()
    #expect(profile.isEligible)
    #expect(await client.lastRequestPath == "api/v1/me")
    #expect(await client.lastRequestMethod == "GET")
    #expect(await client.lastRequestAuthorizationIsAutomatic)
  }

  @Test("프로필 수정은 인증된 PATCH me 응답을 반환한다")
  func updateProfile() async throws {
    let body = Data(#"{"code":"SUCCESS","message":"OK","data":{"id":"user-1","provider":"google","nickname":"축제관객","nicknameConfirmed":true,"termsAcceptedAt":"2026-10-30T00:00:00Z","termsVersion":"2026-10","pushOptIn":false}}"#.utf8)
    let client = StubClient(result: .success(body))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = StubAuthService(loggedIn: true)
    } operation: { AuthRepositoryImpl() }
    let user = try await repository.updateProfile(nickname: "축제관객", termsVersion: "2026-10", pushOptIn: false)
    #expect(user.nicknameConfirmed)
    #expect(await client.lastRequestMethod == "PATCH")
    #expect(await client.lastRequestAuthorizationIsAutomatic)
  }

  @Test("프로필 조회 실패는 전파하고 401에서만 세션을 지운다", arguments: [0, 401, 500])
  func profileFailure(status: Int) async {
    let auth = StubAuthService(loggedIn: true)
    let error: FestiCoreNetworkError = status == 0
      ? .transport(.notConnected)
      : .response(ResponseError(httpStatus: status))
    let client = StubClient(result: .failure(error))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    await #expect(throws: FestiCoreNetworkError.self) { try await repository.fetchProfile() }
    #expect(await auth.signOutCalls == (status == 401 ? 1 : 0))
  }

  @Test("미로그인 프로필 요청은 네트워크 전에 거부한다")
  func profileNotAuthenticated() async {
    let client = StubClient(result: .success(profileBody))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = StubAuthService()
    } operation: { AuthRepositoryImpl() }
    await #expect(throws: AuthDomainError.notAuthenticated) { try await repository.fetchProfile() }
    #expect(await client.calls == 0)
  }

  @Test("프로필 수정의 약관 만료 오류는 세션을 유지하고 전파한다")
  func updateProfileOutdatedTerms() async {
    let auth = StubAuthService(loggedIn: true)
    let client = StubClient(result: .failure(.response(ResponseError(httpStatus: 422))))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    await #expect(throws: FestiCoreNetworkError.self) {
      try await repository.updateProfile(nickname: "축제관객", termsVersion: "2026-09", pushOptIn: false)
    }
    #expect(await client.calls == 1)
    #expect(await auth.isLoggedIn)
  }

  @Test("로그인은 응답 토큰을 기존 인증 세션에 저장한다")
  func signIn() async throws {
    let auth = StubAuthService()
    let client = StubClient(result: .success(loginBody))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }

    let result = try await repository.signIn(with: .google(idToken: "id"))

    #expect(result.newUser)
    #expect(result.user.id == "user-1")
    #expect(await auth.tokens == ["access", "refresh"])
    #expect(await client.calls == 1)
  }

  @Test("로그인 응답 오류는 세션을 저장하지 않고 전파한다")
  func signInFailure() async {
    let auth = StubAuthService()
    let client = StubClient(result: .failure(.response(ResponseError(httpStatus: 401))))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }

    await #expect(throws: FestiCoreNetworkError.self) {
      try await repository.signIn(with: .google(idToken: "invalid"))
    }
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.tokens.isEmpty)
  }

  @Test("use case는 등록된 저장소에 로그인과 로그아웃을 전달한다")
  func useCaseDependency() async throws {
    let auth = StubAuthService()
    let client = StubClient(result: .success(loginBody))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    let useCase = withDependencies {
      $0.authRepository = repository
    } operation: { AuthUseCaseImpl() }

    let result = try await useCase.signIn(with: .google(idToken: "id"))
    #expect(result.user.id == "user-1")
    #expect(await auth.isLoggedIn)
    // 두 번째 요청은 서버 로그아웃 응답이 필요하므로 별도 성공 대역을 등록한다.
    let logoutClient = StubClient(result: .success(Data(#"{"code":"SUCCESS","message":"OK","data":{"success":true}}"#.utf8)))
    let logoutRepository = withDependencies {
      $0.networkClient = logoutClient
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    let logoutUseCase = withDependencies {
      $0.authRepository = logoutRepository
    } operation: { AuthUseCaseImpl() }
    try await logoutUseCase.signOut()
    #expect(await auth.isLoggedIn == false)
  }

  @Test("유효하지 않은 Apple 인가 코드는 네트워크 전에 거부한다")
  func invalidAppleCredential() async {
    let client = StubClient(result: .success(loginBody))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = StubAuthService()
    } operation: { AuthRepositoryImpl() }
    await #expect(throws: AuthDomainError.self) {
      try await repository.signIn(with: .apple(idToken: "id", authorizationCode: ""))
    }
    #expect(await client.calls == 0)
  }

  @Test("긴 Apple 이름은 UTF-16 30 코드 단위로 잘라 로그인에 전달한다")
  func truncatesAppleName() async throws {
    let name = String(repeating: "🎉", count: 16)
    let body = AuthCredential.apple(idToken: "id", authorizationCode: "code", name: name).loginBody
    #expect(body.name == String(repeating: "🎉", count: 15))
    #expect(body.name?.utf16.count == 30)

    let client = StubClient(result: .success(loginBody))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = StubAuthService()
    } operation: { AuthRepositoryImpl() }
    _ = try await repository.signIn(with: .apple(
      idToken: "id", authorizationCode: "code", name: name
    ))
    #expect(await client.calls == 1)
  }

  @Test("Apple 이름을 글자 중간에서 자르지 않고 빈 이름은 생략한다")
  func appleNameGraphemeBoundary() {
    let longName = String(repeating: "가", count: 29) + "👨‍👩‍👧‍👦"
    let body = AuthCredential.apple(idToken: "id", authorizationCode: "code", name: longName).loginBody
    #expect(body.name == String(repeating: "가", count: 29))
    let empty = AuthCredential.apple(idToken: "id", authorizationCode: "code", name: "  \n ").loginBody
    #expect(empty.name == nil)
  }

  @Test("로그아웃 성공은 서버 응답 후 로컬 세션을 지운다")
  func signOut() async throws {
    let auth = StubAuthService(loggedIn: true)
    let client = StubClient(result: .success(Data(#"{"code":"SUCCESS","message":"OK","data":{"success":true}}"#.utf8)))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    try await repository.signOut()
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.signOutCalls == 1)
    #expect(await client.calls == 1)
  }

  @Test("이미 로그아웃 상태라면 네트워크를 호출하지 않는다")
  func alreadySignedOut() async throws {
    let auth = StubAuthService()
    let client = StubClient(result: .failure(.transport(.notConnected)))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    try await repository.signOut()
    #expect(await client.calls == 0)
  }

  @Test("401은 로컬 세션을 삭제한다")
  func unauthorized() async throws {
    let auth = StubAuthService(loggedIn: true)
    let client = StubClient(result: .failure(.response(ResponseError(httpStatus: 401))))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    try await repository.signOut()
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.signOutCalls == 1)
  }

  @Test("전송 실패나 5xx에서 세션을 유지하고 오류를 전파한다", arguments: [0, 500])
  func retainedSessionOnFailure(status: Int) async {
    let auth = StubAuthService(loggedIn: true)
    let error: FestiCoreNetworkError = status == 0
      ? .transport(.notConnected)
      : .response(ResponseError(httpStatus: status))
    let client = StubClient(result: .failure(error))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    await #expect(throws: FestiCoreNetworkError.self) { try await repository.signOut() }
    #expect(await auth.isLoggedIn)
    #expect(await auth.signOutCalls == 0)
  }

  @Test("토큰 갱신이 먼저 세션을 지웠으면 전송 오류여도 로그아웃이 완료된다")
  func refreshClearedSession() async throws {
    let auth = StubAuthService(loggedIn: true)
    let client = StubClient(result: .failure(.transport(.unknown(URLError(.badServerResponse))))) {
      await auth.signOut()
    }
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    try await repository.signOut()
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.signOutCalls == 1)
  }

  @Test("회원 탈퇴 빈 응답 성공 뒤에 로컬 세션을 삭제한다")
  func withdraw() async throws {
    let auth = StubAuthService(loggedIn: true)
    let client = StubClient(result: .success(Data()))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }

    try await repository.withdraw()

    #expect(await client.calls == 1)
    #expect(await client.lastRequestPath == "api/v1/me")
    #expect(await client.lastRequestMethod == "DELETE")
    #expect(await client.lastRequestAuthorizationIsAutomatic)
    #expect(await client.lastRequestParametersAreNil)
    #expect(await auth.isLoggedIn == false)
    #expect(await auth.signOutCalls == 1)
  }

  @Test("미로그인 상태는 회원 탈퇴 요청 전에 거부한다")
  func withdrawNotAuthenticated() async {
    let auth = StubAuthService()
    let client = StubClient(result: .success(Data()))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }

    await #expect(throws: AuthDomainError.notAuthenticated) {
      try await repository.withdraw()
    }
    #expect(await client.calls == 0)
    #expect(await auth.signOutCalls == 0)
  }

  @Test("회원 탈퇴 요청 실패는 오류를 전파하고 인증 만료 시 세션을 지운다", arguments: [0, 401, 500])
  func withdrawFailure(status: Int) async {
    let auth = StubAuthService(loggedIn: true)
    let error: FestiCoreNetworkError = status == 0
      ? .transport(.notConnected)
      : .response(ResponseError(httpStatus: status))
    let client = StubClient(result: .failure(error))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }

    do {
      try await repository.withdraw()
      Issue.record("회원 탈퇴 요청 오류가 전파되지 않음")
    } catch let received as FestiCoreNetworkError {
      let matchesExpectedError: Bool
      switch (status, received) {
      case (0, .transport(.notConnected)):
        matchesExpectedError = true
      case let (expectedStatus, .response(response)):
        matchesExpectedError = response.httpStatus == expectedStatus
      default:
        matchesExpectedError = false
      }
      #expect(matchesExpectedError)
    } catch {
      Issue.record("네트워크 오류 타입이 유지되지 않음")
    }
    #expect(await client.calls == 1)
    #expect(await auth.isLoggedIn == (status != 401))
    #expect(await auth.signOutCalls == (status == 401 ? 1 : 0))
  }

  @Test("회원 탈퇴 UseCase는 저장소의 성공 결과를 전달한다")
  func withdrawUseCase() async throws {
    let auth = StubAuthService(loggedIn: true)
    let client = StubClient(result: .success(Data()))
    let repository = withDependencies {
      $0.networkClient = client
      $0.authService = auth
    } operation: { AuthRepositoryImpl() }
    let useCase = withDependencies {
      $0.authRepository = repository
    } operation: { AuthUseCaseImpl() }

    try await useCase.withdraw()

    #expect(await client.calls == 1)
    #expect(await auth.signOutCalls == 1)
  }

  private var loginBody: Data {
    Data(#"{"code":"SUCCESS","message":"OK","data":{"accessToken":"access","refreshToken":"refresh","newUser":true,"user":{"id":"user-1","provider":"google","email":null,"nickname":null,"nicknameConfirmed":false,"termsAcceptedAt":"2026-10-29T01:02:03.123Z","termsVersion":null,"pushOptIn":false,"profileImageUrl":null}}}"#.utf8)
  }

  private var profileBody: Data {
    Data(#"{"code":"SUCCESS","message":"OK","data":{"id":"user-1","provider":"google","email":null,"nickname":"축제관객","nicknameConfirmed":true,"termsAcceptedAt":"2026-10-30T00:00:00Z","termsVersion":"2026-10","pushOptIn":false,"profileImageUrl":null,"currentTermsVersion":"2026-10","admin":null}}"#.utf8)
  }
}

private actor StubAuthService: AuthService {
  private var loggedIn: Bool
  private(set) var tokens: [String] = []
  private(set) var signOutCalls = 0

  init(loggedIn: Bool = false) { self.loggedIn = loggedIn }

  var isLoggedIn: Bool { loggedIn }
  var refreshToken: String? { tokens.last }
  var currentUserID: String? { nil }

  func signIn(accessToken: String, refreshToken: String) {
    tokens = [accessToken, refreshToken]
    loggedIn = true
  }

  func rememberUserID(_ userID: String) {}

  func signOut() {
    tokens = []
    loggedIn = false
    signOutCalls += 1
  }
}

private actor StubClient: FestiCoreNetworkClient {
  let result: Result<Data, FestiCoreNetworkError>
  let onSend: (@Sendable () async -> Void)?
  private(set) var calls = 0
  private(set) var lastRequestPath: String?
  private(set) var lastRequestMethod: String?
  private(set) var lastRequestAuthorizationIsAutomatic = false
  private(set) var lastRequestParametersAreNil = false

  init(result: Result<Data, FestiCoreNetworkError>, onSend: (@Sendable () async -> Void)? = nil) {
    self.result = result
    self.onSend = onSend
  }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    calls += 1
    lastRequestPath = request.path
    lastRequestMethod = request.method.rawValue
    lastRequestAuthorizationIsAutomatic = request.authorization == .automatic
    lastRequestParametersAreNil = request.parameters == nil
    await onSend?()
    switch result {
    case let .success(data):
      if data.isEmpty, let empty = FestiCoreEmptyResponse() as? T { return empty }
      do { return try JSONDecoder().decode(type, from: data) }
      catch { throw .decoding(.failed(error)) }
    case let .failure(error): throw error
    }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    Issue.record("인증 요청은 응답 타입을 지정해 전송해야 한다")
    throw .request(.invalidURL)
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    Issue.record("사용하지 않는 요청")
    throw .request(.invalidURL)
  }

  func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    Issue.record("사용하지 않는 요청")
    throw .request(.invalidURL)
  }

  func upload(_ request: some FestiCoreFileUploadRequest) async throws(FestiCoreNetworkError) {
    Issue.record("사용하지 않는 요청")
    throw .request(.invalidURL)
  }
}
