//
//  LoginDelegate.swift
//  AuthInterface
//
//  Created by FestiCore on 10/29/26.
//

import AuthDomainInterface
import ComposableArchitecture

@CasePathable
public enum LoginDelegate: Equatable, Sendable {
  /// 로그인 버튼을 눌렀다. 부모가 시트 상태를 확인한 뒤 `view(.signIn)`으로 로그인을 시작한다.
  case signInRequested(OAuthProvider)
  case signedIn(AuthLoginResult)
  case closeRequested
}
