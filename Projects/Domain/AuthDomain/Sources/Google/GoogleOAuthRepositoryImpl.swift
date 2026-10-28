//
//  GoogleOAuthRepositoryImpl.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import AuthDomainInterface
import Foundation
import GoogleSignIn
import UIKit

@MainActor
public final class GoogleOAuthRepositoryImpl: GoogleOAuthRepository {
  private let configuration: @MainActor () -> GoogleOAuthConfiguration?
  private let presentingController: @MainActor () -> UIViewController?
  private let signIn: @MainActor (GoogleOAuthConfiguration, UIViewController) async throws -> GoogleOAuthTokens
  private let signOut: @MainActor () -> Void
  private let gate: GoogleOAuthRequestGate?

  public nonisolated init() {
    configuration = GoogleOAuthConfiguration.fromMainBundle
    presentingController = { Self.activePresentingController() }
    signIn = { configuration, presenter in
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(
        clientID: configuration.clientID,
        serverClientID: configuration.serverClientID
      )
      let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
      return GoogleOAuthTokens(
        idToken: result.user.idToken?.tokenString,
        serverAuthCode: result.serverAuthCode
      )
    }
    signOut = { GIDSignIn.sharedInstance.signOut() }
    gate = nil
  }

  init(
    configuration: @escaping @MainActor () -> GoogleOAuthConfiguration?,
    presentingController: @escaping @MainActor () -> UIViewController?,
    signIn: @escaping @MainActor (GoogleOAuthConfiguration, UIViewController) async throws -> GoogleOAuthTokens,
    signOut: @escaping @MainActor () -> Void,
    gate: GoogleOAuthRequestGate
  ) {
    self.configuration = configuration
    self.presentingController = presentingController
    self.signIn = signIn
    self.signOut = signOut
    self.gate = gate
  }

  public func credential() async throws -> AuthCredential {
    let gate = gate ?? .shared
    try gate.begin()
    defer { gate.end() }

    do {
      try Task.checkCancellation()
      guard let configuration = configuration() else {
        throw AuthDomainError.configurationMissing
      }
      guard let presenter = presentingController() else {
        throw AuthDomainError.missingPresentingController
      }
      let tokens = try await signIn(configuration, presenter)
      // Google SDK retains provider state; clear it even when cancellation arrived during sign-in.
      defer { signOut() }
      try Task.checkCancellation()
      return try tokens.credential()
    } catch is CancellationError {
      throw AuthDomainError.userCancelled
    } catch let error as AuthDomainError {
      throw error
    } catch {
      if Task.isCancelled { throw AuthDomainError.userCancelled }
      let nsError = error as NSError
      if nsError.domain == kGIDSignInErrorDomain
        && nsError.code == GIDSignInError.canceled.rawValue {
        throw AuthDomainError.userCancelled
      }
      throw AuthDomainError.providerFailure
    }
  }

  private static func activePresentingController() -> UIViewController? {
    guard let root = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive })?
      .windows.first(where: { $0.isKeyWindow })?.rootViewController
    else { return nil }

    var controller = root
    while let presented = controller.presentedViewController {
      controller = presented
    }
    return controller
  }
}

struct GoogleOAuthConfiguration {
  let clientID: String
  let serverClientID: String?

  static func fromMainBundle() -> Self? {
    guard let clientID = validID(Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String) else {
      return nil
    }
    let serverClientID = validID(Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String)
    return Self(clientID: clientID, serverClientID: serverClientID)
  }

  private static func validID(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
      !value.isEmpty, !value.contains("$(")
    else { return nil }
    return value
  }
}

struct GoogleOAuthTokens {
  let idToken: String?
  let serverAuthCode: String?

  func credential() throws -> AuthCredential {
    guard let idToken, !idToken.isEmpty else { throw AuthDomainError.missingIDToken }
    return .google(
      idToken: idToken,
      serverAuthCode: serverAuthCode.flatMap { $0.isEmpty ? nil : $0 }
    )
  }
}

@MainActor
final class GoogleOAuthRequestGate {
  static let shared = GoogleOAuthRequestGate()
  private var isActive = false

  func begin() throws {
    guard !isActive else { throw AuthDomainError.requestInProgress }
    isActive = true
  }

  func end() { isActive = false }
}
