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
    await authService.signIn(
      accessToken: response.data.accessToken,
      refreshToken: response.data.refreshToken
    )
    await authService.rememberUserID(response.data.user.id)
    return response.data.toDomain()
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
      await clearUnauthorizedSession(error, sessionID: sessionID)
      throw error
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
      await clearUnauthorizedSession(error, sessionID: sessionID)
      throw error
    }
  }

  private func clearUnauthorizedSession(_ error: any Error, sessionID: UUID) async {
    if let networkError = error as? FestiCoreNetworkError,
       case let .response(response) = networkError,
       response.isUnauthorized {
      _ = await authService.signOut(ifSessionIDMatches: sessionID)
    }
  }

  public func signOut() async throws {
    guard let sessionID = await authService.authenticatedSessionID else { return }

    do {
      let response = try await client.send(AuthRequest.logout(sessionID: sessionID), as: AuthLogoutResponseDTO.self)
      guard response.code == "SUCCESS", response.data.success else {
        throw AuthDomainError.invalidResponse
      }
      _ = await authService.signOut(ifSessionIDMatches: sessionID)
    } catch {
      // 갱신 실패가 먼저 세션을 지웠다면 요청 오류와 관계없이 로그아웃을 마친 상태다.
      guard await authService.isLoggedIn else { return }
      if let networkError = error as? FestiCoreNetworkError,
         case let .response(response) = networkError,
         response.isUnauthorized {
        _ = await authService.signOut(ifSessionIDMatches: sessionID)
        return
      }
      throw error
    }
  }

  public func withdraw() async throws {
    guard let sessionID = await authService.authenticatedSessionID else {
      throw AuthDomainError.notAuthenticated
    }

    do {
      _ = try await client.send(AuthRequest.withdraw(sessionID: sessionID), as: FestiCoreEmptyResponse.self)
      _ = await authService.signOut(ifSessionIDMatches: sessionID)
    } catch {
      await clearUnauthorizedSession(error, sessionID: sessionID)
      throw error
    }
  }
}
