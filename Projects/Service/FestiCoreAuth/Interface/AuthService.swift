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
  /// 서버 로그인 응답을 확정 전 임시 세션으로 둔다. Keychain과 인증 요청 자격 증명은 바꾸지 않는다.
  func stageSession(accessToken: String, refreshToken: String) async -> UUID
  /// 같은 임시 세션일 때만 Keychain에 확정하고 true를 돌려준다.
  func commitSession(_ id: UUID) async -> Bool
  /// 같은 임시 세션일 때만 버리고 true를 돌려준다. 확정 세션은 건드리지 않는다.
  func discardSession(_ id: UUID) async -> Bool
  /// 현재 확정 세션이 그 식별자일 때만 로그아웃하고 true를 돌려준다. 진행 중인 임시 세션은 남긴다.
  func signOut(ifSession id: UUID) async -> Bool
  func rememberUserID(_ userID: String) async
  /// 로컬 자격 증명 삭제가 완료되었을 때만 true를 반환한다.
  @discardableResult
  func signOut() async -> Bool
}

public extension Notification.Name {
  static let festiCoreAuthSessionDidExpire = Notification.Name("festicore.auth.session.didExpire")
}
