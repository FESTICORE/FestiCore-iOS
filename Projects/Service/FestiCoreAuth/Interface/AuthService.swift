//
//  AuthService.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/22/26.
//

import Foundation

public enum AuthRevocationKind: Sendable {
  case signOut
  case withdrawal
}

public protocol AuthService: Sendable {
  var isLoggedIn: Bool { get async }
  var refreshToken: String? { get async }
  var currentUserID: String? { get async }
  /// 로그인마다 바뀌며 같은 세션의 토큰 갱신 중에는 유지된다.
  var sessionID: UUID { get async }
  /// 로그인된 경우 토큰과 동일한 저장소 스냅샷에서 얻은 세션 식별자.
  var authenticatedSessionID: UUID? { get async }
  /// 세션에 한정한 로컬 삭제가 실패해 재시도가 필요한지 나타낸다.
  var hasPendingLocalClear: Bool { get async }
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
  /// 오래된 요청이 새 로그인 세션을 지우지 않도록 현재 세션을 원자적으로 확인한다.
  func signOut(ifSessionIDMatches sessionID: UUID) async -> Bool
  /// 서버 요청 전에 복원 차단 기록을 디스크에 확인한 뒤 요청을 허용한다.
  func prepareRevocation(_ kind: AuthRevocationKind) async -> Bool
  /// 서버 결과가 불명확해도 기록은 유지하고 이번 요청만 종료한다.
  func finishRevocationRequest() async
  /// 서버 결과를 확인했음을 디스크에 기록한다. 기록 실패 시 로컬 완료로 보고하지 않는다.
  func confirmSignOut() async -> Bool
  func confirmWithdrawalAuthorizationRejected() async -> Bool
  /// 요청만 기록되고 서버 결과가 확인되지 않은 채 인증 토큰을 복원할 수 없는 상태다.
  var hasUnconfirmedRevocation: Bool { get async }
  /// 서버 결과가 불명확한 요청의 로컬 토큰만 다시 삭제하고 요청 기록은 유지한다.
  func retryUnconfirmedLocalCleanup() async -> Bool
  /// 서버 로그아웃 뒤 또는 재시작 뒤 로컬 토큰 삭제만 남았는지 확인한다.
  var hasPendingSignOutCleanup: Bool { get async }
  /// 탈퇴 완료 여부를 확인할 수 없는 상태에서 로컬 토큰 정리만 남았는지 확인한다.
  var hasPendingWithdrawalAuthorizationCleanup: Bool { get async }
  /// 서버 탈퇴가 성공했지만 로컬 자격 증명 정리가 남아 있는지 확인한다.
  var hasPendingWithdrawalCleanup: Bool { get async }
  /// 서버 탈퇴 성공 뒤 로컬 자격 증명을 정리하고, 실패 시 재시도 상태를 유지한다.
  @discardableResult
  func completeWithdrawal() async -> Bool
}

public extension AuthService {
  var hasPendingLocalClear: Bool { get async { false } }
  func prepareRevocation(_ kind: AuthRevocationKind) async -> Bool { false }
  func finishRevocationRequest() async {}
  func confirmSignOut() async -> Bool { false }
  func confirmWithdrawalAuthorizationRejected() async -> Bool { false }
  var hasUnconfirmedRevocation: Bool { get async { false } }
  func retryUnconfirmedLocalCleanup() async -> Bool { false }
  var hasPendingSignOutCleanup: Bool { get async { false } }
  var hasPendingWithdrawalAuthorizationCleanup: Bool { get async { false } }
  var hasPendingWithdrawalCleanup: Bool { get async { false } }

  @discardableResult
  func completeWithdrawal() async -> Bool { await signOut() }
}

public extension Notification.Name {
  static let festiCoreAuthSessionDidExpire = Notification.Name("festicore.auth.session.didExpire")
}
