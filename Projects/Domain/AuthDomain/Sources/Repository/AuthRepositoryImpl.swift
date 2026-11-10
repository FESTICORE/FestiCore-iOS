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

/// `AuthInterface`의 라이브 구현이다. 공용 `networkClient`로 인증 요청을 보내고,
/// 검증한 로그인 응답과 세션 변경은 공용 `authService`에 저장한다.
public struct AuthRepositoryImpl: AuthInterface {
  @Dependency(\.networkClient) private var client
  @Dependency(\.authService) private var authService

  public init() {}

  /// 로그인은 네트워크 오류를 `AuthDomainError`로 매핑하지 않고 그대로 던진다.
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
    guard let sessionID = await authService.authenticatedSessionID else {
      throw AuthDomainError.notAuthenticated
    }
    do {
      let response = try await client.send(AuthRequest.me(sessionID: sessionID), as: AuthProfileResponseDTO.self)
      guard response.code == "SUCCESS", !response.data.currentTermsVersion.isEmpty else {
        throw AuthDomainError.invalidResponse
      }
      return response.data.toDomain()
    } catch {
      try await clearUnauthorizedSession(error, sessionID: sessionID)
      throw AuthDomainError.mapping(error)
    }
  }

  public func updateProfile(nickname: String, termsVersion: String, pushOptIn: Bool) async throws -> AuthUser {
    guard let sessionID = await authService.authenticatedSessionID else {
      throw AuthDomainError.notAuthenticated
    }
    guard !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !termsVersion.isEmpty else { throw AuthDomainError.invalidResponse }
    do {
      let response = try await client.send(
        AuthRequest.updateMe(body: AuthProfileUpdateBody(
          nickname: nickname, termsVersion: termsVersion, pushOptIn: pushOptIn
        ), sessionID: sessionID),
        as: AuthProfileUpdateResponseDTO.self
      )
      guard response.code == "SUCCESS" else { throw AuthDomainError.invalidResponse }
      return response.data.toDomain()
    } catch {
      try await clearUnauthorizedSession(error, sessionID: sessionID)
      throw AuthDomainError.mapping(error)
    }
  }

  /// 닉네임 변경은 네트워크 오류를 `AuthDomainError`로 매핑하지 않고 그대로 던진다(호출 화면이 `AuthDomainError` 외 오류를 실패로 본다).
  public func updateNickname(_ nickname: String) async throws -> AuthUser {
    guard let sessionID = await authService.authenticatedSessionID else {
      throw AuthDomainError.notAuthenticated
    }
    let trimmed = AuthNicknameRule.trimmed(nickname)
    guard AuthNicknameRule.isValid(trimmed) else { throw AuthDomainError.invalidNickname }
    do {
      let response = try await client.send(
        AuthRequest.updateNickname(body: AuthNicknameUpdateBody(nickname: trimmed), sessionID: sessionID),
        as: AuthProfileUpdateResponseDTO.self
      )
      guard response.code == "SUCCESS" else { throw AuthDomainError.invalidResponse }
      return response.data.toDomain()
    } catch {
      try await clearUnauthorizedSession(error, sessionID: sessionID)
      throw error
    }
  }

  private func clearUnauthorizedSession(_ error: any Error, sessionID: UUID) async throws {
    if let networkError = error as? FestiCoreNetworkError,
       case let .response(response) = networkError,
       response.isUnauthorized {
      let cleared = await authService.signOut(ifSessionIDMatches: sessionID)
      if !cleared, await authService.hasPendingLocalClear {
        throw AuthDomainError.localSessionClearFailed
      }
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
    guard let sessionID = await authService.authenticatedSessionID else {
      guard await authService.signOut() else { throw AuthDomainError.localSessionClearFailed }
      return
    }
    guard await authService.prepareRevocation(.signOut, ifSessionIDMatches: sessionID) else {
      throw AuthDomainError.localSessionClearFailed
    }

    do {
      let response = try await client.send(AuthRequest.logout(sessionID: sessionID), as: AuthLogoutResponseDTO.self)
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
        return
      }
      await authService.finishRevocationRequest()
      throw AuthDomainError.mapping(error)
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
    guard let sessionID = await authService.authenticatedSessionID else {
      throw AuthDomainError.notAuthenticated
    }
    guard await authService.prepareRevocation(.withdrawal, ifSessionIDMatches: sessionID) else {
      throw AuthDomainError.localSessionClearFailed
    }

    do {
      _ = try await client.send(AuthRequest.withdraw(sessionID: sessionID), as: FestiCoreEmptyResponse.self)
    } catch {
      if let networkError = error as? FestiCoreNetworkError,
         case let .response(response) = networkError,
         response.isUnauthorized {
        guard await authService.confirmWithdrawalAuthorizationRejected() else {
          await authService.finishRevocationRequest()
          throw AuthDomainError.localSessionClearFailed
        }
      }
      try await clearUnauthorizedSession(error, sessionID: sessionID)
      await authService.finishRevocationRequest()
      throw AuthDomainError.mapping(error)
    }
    guard await authService.completeWithdrawal() else { throw AuthDomainError.localSessionClearFailed }
  }

  public func commitSession(_ id: UUID) async -> Bool {
    return await authService.commitSession(id)
  }

  public func discardSession(_ id: UUID) async -> Bool {
    return await authService.discardSession(id)
  }

  public func signOut(ifSession id: UUID) async -> Bool {
    return await authService.signOut(ifSession: id)
  }
}
