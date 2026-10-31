//
//  AuthService.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/22/26.
//

import Foundation

public protocol AuthService: Sendable {
  var isLoggedIn: Bool { get async }
  var refreshToken: String? { get async }
  var currentUserID: String? { get async }
  /// 로그인마다 바뀌며 같은 세션의 토큰 갱신 중에는 유지된다.
  var sessionID: UUID { get async }
  /// 로그인된 경우 토큰과 동일한 저장소 스냅샷에서 얻은 세션 식별자.
  var authenticatedSessionID: UUID? { get async }
  func signIn(accessToken: String, refreshToken: String) async
  func rememberUserID(_ userID: String) async
  func signOut() async
  /// 오래된 요청이 새 로그인 세션을 지우지 않도록 현재 세션을 원자적으로 확인한다.
  func signOut(ifSessionIDMatches sessionID: UUID) async -> Bool
}

public extension Notification.Name {
  static let festiCoreAuthSessionDidExpire = Notification.Name("festicore.auth.session.didExpire")
}
