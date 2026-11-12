//
//  LoginProviderButtons.swift
//  Login
//
//  Created by FestiCore on 11/12/26.
//

import AuthDomainInterface
import FestiCoreDesignKit
import SwiftUI

/// S14 A 로그인 화면과 로그인 시트가 함께 쓰는 Apple·Google 로그인 버튼 묶음
struct LoginProviderButtons: View {
  let spacing: CGFloat
  let onSignIn: (OAuthProvider) -> Void

  var body: some View {
    VStack(spacing: spacing) {
      FCLoginButton(.apple) { onSignIn(.apple) }
      FCLoginButton(.google) { onSignIn(.google) }
    }
  }
}
