//
//  AppleOAuthRepositoryImpl.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import AuthenticationServices
import FestiCoreAuthDomainInterface
import Foundation
import UIKit

public struct AppleOAuthRepositoryImpl: AppleOAuthRepository {
  public init() {}

  @MainActor
  public func credential() async throws -> AuthCredential {
    try await AppleOAuthFlow.shared.credential()
  }
}

@MainActor
final class AppleOAuthFlow: NSObject, ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding {
  static let shared = AppleOAuthFlow()

  private let anchorProvider: @MainActor () -> ASPresentationAnchor?
  private let requestStarter: @MainActor (ASAuthorizationController) -> Void
  private var anchor: ASPresentationAnchor?
  private var controller: ASAuthorizationController?
  private var continuation: CheckedContinuation<AuthCredential, Error>?
  private var requestID: UUID?
  var hasPendingRequest: Bool { continuation != nil }
  var pendingRequestID: UUID? { requestID }

  init(anchorProvider: @escaping @MainActor () -> ASPresentationAnchor? = {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }?
      .keyWindow
  }, requestStarter: @escaping @MainActor (ASAuthorizationController) -> Void = {
    $0.performRequests()
  }) {
    self.anchorProvider = anchorProvider
    self.requestStarter = requestStarter
  }

  func credential() async throws -> AuthCredential {
    guard continuation == nil else { throw AuthDomainError.requestInProgress }
    guard let window = anchorProvider() else { throw AuthDomainError.missingPresentingController }
    guard !Task.isCancelled else { throw AuthDomainError.userCancelled }
    let requestID = UUID()

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        guard !Task.isCancelled else {
          continuation.resume(throwing: AuthDomainError.userCancelled)
          return
        }
        self.anchor = window
        self.requestID = requestID
        self.continuation = continuation
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        self.controller = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        requestStarter(controller)
      }
    } onCancel: {
      Task { @MainActor [weak self] in
        self?.cancel(requestID: requestID)
      }
    }
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    anchor ?? ASPresentationAnchor()
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard self.controller === controller else { return }
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      finish(.failure(AuthDomainError.invalidCredential))
      return
    }
    do {
      finish(.success(try AppleOAuthCredentialMapper.map(
        identityToken: credential.identityToken,
        authorizationCode: credential.authorizationCode,
        fullName: credential.fullName
      )))
    } catch {
      finish(.failure(error))
    }
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    guard self.controller === controller else { return }
    let nsError = error as NSError
    let mapped: AuthDomainError = nsError.domain == ASAuthorizationError.errorDomain
      && nsError.code == ASAuthorizationError.canceled.rawValue
      ? .userCancelled : .providerFailure
    finish(.failure(mapped))
  }

  func cancel(requestID: UUID) {
    guard self.requestID == requestID, continuation != nil else { return }
    controller?.cancel()
    finish(.failure(AuthDomainError.userCancelled))
  }

  func finish(_ result: Result<AuthCredential, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    requestID = nil
    controller = nil
    anchor = nil
    continuation.resume(with: result)
  }
}
