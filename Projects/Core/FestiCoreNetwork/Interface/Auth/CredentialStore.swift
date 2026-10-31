//
//  CredentialStore.swift
//  FestiCoreNetworkInterface
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

/// 토큰 저장소 추상. 앱이 구현(키체인 등)해 주입한다.
/// 클라이언트는 이걸 통해 토큰을 읽고, refresh 된 토큰을 다시 저장한다.
public protocol CredentialStore: Sendable {
  /// 토큰과 로그인 세션을 한 시점에서 읽는다.
  func sessionSnapshot() -> FestiCoreCredentialSession?
  /// 저장된 토큰 (없으면 nil)
  func load() -> FestiCoreCredential?
  /// 토큰 저장 (refresh 후 영속화)
  func save(_ credential: FestiCoreCredential)
  /// 갱신 시작 시점의 세션 식별자. 토큰 값이 같아도 재로그인은 다른 세션이다.
  func revision(matching current: FestiCoreCredential) -> UUID?
  /// 현재 세션이 갱신을 시작한 세션과 같을 때만 원자적으로 교체한다.
  @discardableResult
  func replace(_ credential: FestiCoreCredential, ifCurrent current: FestiCoreCredential, revision: UUID) -> Bool
  /// 토큰 삭제 (로그아웃 등)
  func clear()
}

public struct FestiCoreCredentialSession: Sendable, Equatable {
  public let credential: FestiCoreCredential
  public let id: UUID

  public init(credential: FestiCoreCredential, id: UUID) {
    self.credential = credential
    self.id = id
  }
}
