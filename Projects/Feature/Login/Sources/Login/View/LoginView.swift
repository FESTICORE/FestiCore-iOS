//
//  LoginView.swift
//  Login
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import FestiCoreSharedUI
import SwiftUI

/// 로그인이 필요할 때 띄우는 소셜 로그인 시트
@ViewAction(for: LoginFeature.self)
public struct LoginView: View {
  @Bindable public var store: StoreOf<LoginFeature>

  public init(store: StoreOf<LoginFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      FCLoginSheet(
        title: copy.title,
        message: copy.message,
        onApple: { send(.signInTapped(.apple)) },
        onGoogle: { send(.signInTapped(.google)) }
      )
      if let message = store.visibleMessage {
        Text(message)
          .foregroundStyle(.red)
          .padding(.bottom, 16)
      }
    }
  }
}

extension LoginView {
  /// 로그인을 요청한 문맥에 맞춘 시트 문구
  private var copy: (title: String, message: String) {
    switch store.context {
    case .profile:
      return ("계정 정보를 보려면 로그인이 필요해요", "로그인 후 프로필을 확인할 수 있어요.")
    case .flag:
      return ("깃발을 팔로우 하려면 로그인이 필요해요", "내 취향의 깃발을 팔로우하고,\n함께 페스티벌을 즐길 사람들과 크루를 만들어봐요.")
    case .bookmark:
      return ("축제를 저장하려면 로그인이 필요해요", "로그인 후 선택한 축제를 저장할 수 있어요.")
    }
  }
}

#Preview {
  LoginView(store: Store(initialState: LoginFeature.State()) { LoginFeature() })
}
