//
//  AuthRepositoryImpl.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Dependencies
import APIEndpoint
import AuthDomainInterface
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import Foundation

public struct AuthRepositoryImpl: AuthInterface {
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
    let sessionID = await authService.stageSession(
      accessToken: response.data.accessToken,
      refreshToken: response.data.refreshToken
    )
    await authService.rememberUserID(response.data.user.id)
    let result = response.data.toDomain()
    return AuthLoginResult(newUser: result.newUser, user: result.user, sessionID: sessionID)
  }

  public func fetchProfile() async throws -> AuthProfile {
    guard await authService.isLoggedIn else { throw AuthDomainError.notAuthenticated }
    do {
      let response = try await client.send(AuthRequest.me, as: AuthProfileResponseDTO.self)
      guard response.code == "SUCCESS", !response.data.currentTermsVersion.isEmpty else {
        throw AuthDomainError.invalidResponse
      }
      return response.data.toDomain()
    } catch {
      try await clearUnauthorizedSession(error)
      throw error
    }
  }

  public func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    guard await authService.isLoggedIn else { throw AuthDomainError.notAuthenticated }
    guard !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !termsVersion.isEmpty else { throw AuthDomainError.invalidResponse }
    do {
      let response = try await client.send(
        AuthRequest.updateMe(body: AuthProfileUpdateBody(
          nickname: nickname, termsVersion: termsVersion, pushOptIn: pushOptIn
        )),
        as: AuthProfileUpdateResponseDTO.self
      )
      guard response.code == "SUCCESS" else { throw AuthDomainError.invalidResponse }
      return response.data.toDomain()
    } catch {
      try await clearUnauthorizedSession(error)
      throw error
    }
  }

  private func clearUnauthorizedSession(_ error: any Error) async throws {
    if let networkError = error as? FestiCoreNetworkError,
       case let .response(response) = networkError,
       response.isUnauthorized {
      guard await authService.signOut() else { throw AuthDomainError.localSessionClearFailed }
    }
  }

  public func signOut() async throws {
    if await authService.hasUnconfirmedRevocation {
      guard await authService.retryUnconfirmedLocalCleanup() else {
        throw AuthDomainError.localSessionClearFailed
      }
      throw AuthDomainError.revocationOutcomeUnknown
    }
    if await authService.hasPendingSignOutCleanup {
      guard await authService.signOut() else { throw AuthDomainError.localSessionClearFailed }
      return
    }
    guard await authService.isLoggedIn else {
      guard await authService.signOut() else { throw AuthDomainError.localSessionClearFailed }
      return
    }
    guard await authService.prepareRevocation(.signOut) else {
      throw AuthDomainError.localSessionClearFailed
    }

    do {
      let response = try await client.send(AuthRequest.logout, as: AuthLogoutResponseDTO.self)
      guard response.code == "SUCCESS", response.data.success else {
        throw AuthDomainError.invalidResponse
      }
    } catch {
      if let networkError = error as? FestiCoreNetworkError,
         case let .response(response) = networkError,
         response.isUnauthorized {
        guard await authService.confirmSignOut() else {
          await authService.finishRevocationRequest()
          throw AuthDomainError.localSessionClearFailed
        }
        guard await authService.signOut() else { throw AuthDomainError.localSessionClearFailed }
        return
      }
      if await authService.hasUnconfirmedRevocation {
        await authService.finishRevocationRequest()
        throw AuthDomainError.revocationOutcomeUnknown
      }
      // 갱신 실패가 먼저 세션을 지웠다면 요청 오류와 관계없이 로그아웃을 마친 상태다.
      guard await authService.isLoggedIn else {
        guard await authService.signOut() else { throw AuthDomainError.localSessionClearFailed }
        return
      }
      await authService.finishRevocationRequest()
      throw error
    }
    guard await authService.confirmSignOut() else {
      await authService.finishRevocationRequest()
      throw AuthDomainError.localSessionClearFailed
    }
    guard await authService.signOut() else { throw AuthDomainError.localSessionClearFailed }
  }

  public func withdraw() async throws {
    if await authService.hasPendingWithdrawalCleanup {
      guard await authService.completeWithdrawal() else { throw AuthDomainError.localSessionClearFailed }
      return
    }
    if await authService.hasUnconfirmedRevocation {
      guard await authService.retryUnconfirmedLocalCleanup() else {
        throw AuthDomainError.localSessionClearFailed
      }
      throw AuthDomainError.revocationOutcomeUnknown
    }
    if await authService.hasPendingWithdrawalAuthorizationCleanup {
      guard await authService.signOut() else { throw AuthDomainError.localSessionClearFailed }
      throw AuthDomainError.notAuthenticated
    }
    guard await authService.isLoggedIn else { throw AuthDomainError.notAuthenticated }
    guard await authService.prepareRevocation(.withdrawal) else {
      throw AuthDomainError.localSessionClearFailed
    }

    do {
      _ = try await client.send(AuthRequest.withdraw, as: FestiCoreEmptyResponse.self)
    } catch {
      if let networkError = error as? FestiCoreNetworkError,
         case let .response(response) = networkError,
         response.isUnauthorized {
        guard await authService.confirmWithdrawalAuthorizationRejected() else {
          await authService.finishRevocationRequest()
          throw AuthDomainError.localSessionClearFailed
        }
      }
      try await clearUnauthorizedSession(error)
      await authService.finishRevocationRequest()
      throw error
    }
    guard await authService.completeWithdrawal() else { throw AuthDomainError.localSessionClearFailed }
  }
}
