//
//  AuthRepositoryImpl.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import FestiCoreAPIEndpoint
import FestiCoreAuthDomainInterface
import FestiCoreAuthInterface
import FestiCoreNetworkInterface

public struct AuthRepositoryImpl: AuthRepository {
  @Dependency(\.networkClient) private var client
  @Dependency(\.authService) private var authService

  public init() {}

  public func signIn(with credential: AuthCredential) async throws -> AuthLoginResult {
    switch credential {
    case let .google(idToken, serverAuthCode):
      guard !idToken.isEmpty, serverAuthCode != "" else { throw AuthDomainError.invalidCredential }
    case let .apple(idToken, authorizationCode, _):
      guard !idToken.isEmpty, !authorizationCode.isEmpty else {
        throw AuthDomainError.invalidCredential
      }
    }
    let response = try await client.send(
      AuthRequest.login(body: credential.loginBody),
      as: AuthLoginResponseDTO.self
    )
    guard response.code == "SUCCESS",
          !response.data.accessToken.isEmpty,
          !response.data.refreshToken.isEmpty else {
      throw AuthDomainError.invalidResponse
    }
    await authService.signIn(
      accessToken: response.data.accessToken,
      refreshToken: response.data.refreshToken
    )
    return response.data.result
  }

  public func signOut() async throws {
    guard await authService.isLoggedIn else { return }

    do {
      let response = try await client.send(AuthRequest.logout, as: AuthLogoutResponseDTO.self)
      guard response.code == "SUCCESS", response.data.success else {
        throw AuthDomainError.invalidResponse
      }
      await authService.signOut()
    } catch {
      // 갱신 실패가 먼저 세션을 지웠다면 요청 오류와 관계없이 로그아웃을 마친 상태다.
      guard await authService.isLoggedIn else { return }
      if let networkError = error as? FestiCoreNetworkError,
         case let .response(response) = networkError,
         response.isUnauthorized {
        await authService.signOut()
        return
      }
      throw error
    }
  }
}
