//
//  CredentialStore.swift
//  FestiCoreNetworkInterface
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

/// 갱신된 토큰 쌍을 안전하게 저장하지 못했다.
public enum CredentialStoreError: Error {
  case persistenceFailed
}

/// 토큰 저장소 추상. 앱이 구현(키체인 등)해 주입한다.
/// 클라이언트는 이걸 통해 토큰을 읽고, refresh 된 토큰을 다시 저장한다.
public protocol CredentialStore: Sendable {
  /// 저장된 토큰 (없으면 nil)
  func load() -> FestiCoreCredential?
  /// 토큰 저장 결과. 영속화 실패를 성공으로 취급하지 않는다.
  @discardableResult
  func save(_ credential: FestiCoreCredential) -> Bool
  /// 갱신 시작 시점의 세션 식별자. 토큰 값이 같아도 재로그인은 다른 세션이다.
  func revision(matching current: FestiCoreCredential) -> UUID?
  /// 현재 세션이 갱신을 시작한 세션과 같을 때만 원자적으로 교체한다.
  /// 오래된 세션이면 false, 저장 실패면 오류를 던진다.
  @discardableResult
  func replace(_ credential: FestiCoreCredential, ifCurrent current: FestiCoreCredential, revision: UUID) throws -> Bool
  /// 토큰 삭제 및 무효화가 모두 성공했는지 반환한다.
  @discardableResult
  func clear() -> Bool
}
