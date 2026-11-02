//
//  LoginView.swift
//  Login
//
//  Created by FestiCore on 11/2/26.
//

import FestiCoreSharedUI
import SwiftUI

/// 로그인이 필요할 때 띄우는 소셜 로그인 시트
public struct LoginView: View {
  private let title: String
  private let message: String
  private let errorMessage: String?
  private let onApple: () -> Void
  private let onGoogle: () -> Void

  public init(
    title: String,
    message: String,
    errorMessage: String?,
    onApple: @escaping () -> Void,
    onGoogle: @escaping () -> Void
  ) {
    self.title = title
    self.message = message
    self.errorMessage = errorMessage
    self.onApple = onApple
    self.onGoogle = onGoogle
  }

  public var body: some View {
    VStack {
      FCLoginSheet(
        title: title,
        message: message,
        onApple: onApple,
        onGoogle: onGoogle
      )
      if let errorMessage {
        Text(errorMessage)
          .foregroundStyle(.red)
          .padding(.bottom, 16)
      }
    }
  }
}
