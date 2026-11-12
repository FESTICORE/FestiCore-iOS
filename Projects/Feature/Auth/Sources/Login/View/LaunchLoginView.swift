//
//  LaunchLoginView.swift
//  Login
//
//  Created by FestiCore on 11/12/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// 로그아웃 상태로 앱을 켰을 때 홈 위를 덮는 S14 A 로그인 첫 진입 화면. 로그인 시트와 같은 `LoginFeature`를 쓴다.
@ViewAction(for: LoginFeature.self)
public struct LaunchLoginView: View {
  @Bindable public var store: StoreOf<LoginFeature>

  public init(store: StoreOf<LoginFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      ZStack {
        decorations
        introduction()
      }
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity
      )
      actions()
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color.ignoresSafeArea())
  }
}

private extension LaunchLoginView {
  /// 시안 393×852 기준 장식 별 위치(비율)와 색
  struct Decoration {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let isBurst: Bool
    let color: Color
  }

  static let decorations: [Decoration] = [
    Decoration(
      x: 0.43,
      y: 0.075,
      size: 12,
      isBurst: false,
      color: .accentPointPurple
    ),
    Decoration(
      x: 0.12,
      y: 0.112,
      size: 20,
      isBurst: true,
      color: .accentPointLime
    ),
    Decoration(
      x: 0.76,
      y: 0.126,
      size: 24,
      isBurst: true,
      color: .accentPointPink
    ),
    Decoration(
      x: 0.28,
      y: 0.199,
      size: 20,
      isBurst: true,
      color: .accentPointPurple
    ),
    Decoration(
      x: 0.64,
      y: 0.216,
      size: 12,
      isBurst: false,
      color: .accentPointPurple
    ),
    Decoration(
      x: 0.92,
      y: 0.23,
      size: 14,
      isBurst: false,
      color: .accentPointLime
    ),
    Decoration(
      x: 0.09,
      y: 0.25,
      size: 14,
      isBurst: false,
      color: .accentPointPurple
    ),
    Decoration(
      x: 0.04,
      y: 0.394,
      size: 14,
      isBurst: true,
      color: .accentPointLime
    ),
    Decoration(
      x: 0.96,
      y: 0.373,
      size: 20,
      isBurst: true,
      color: .accentPointPurple
    ),
    Decoration(
      x: 0.06,
      y: 0.551,
      size: 22,
      isBurst: true,
      color: .accentPointPink
    ),
    Decoration(
      x: 0.95,
      y: 0.624,
      size: 12,
      isBurst: false,
      color: .accentPointPurple
    ),
    Decoration(
      x: 0.18,
      y: 0.695,
      size: 16,
      isBurst: false,
      color: .accentPointLime
    ),
    Decoration(
      x: 0.82,
      y: 0.704,
      size: 14,
      isBurst: false,
      color: .accentPointPink
    ),
  ]

  /// 화면 크기에 맞춰 흩뿌린 장식 별. 읽기 도구에서는 숨긴다.
  var decorations: some View {
    GeometryReader { proxy in
      ForEach(
        Self.decorations.indices,
        id: \.self
      ) { index in
        let item = Self.decorations[index]
        Image(systemName: item.isBurst ? "seal.fill" : "sparkle")
          .resizable()
          .scaledToFit()
          .frame(
            width: item.size,
            height: item.size
          )
          .foregroundStyle(item.color)
          .position(
            x: proxy.size.width * item.x,
            y: proxy.size.height * item.y
          )
      }
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder
  func introduction() -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
      Text("가장 뜨거운 현장 속으로")
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text("로그인하면 깃발을 팔로우하고 크루를 만들 수 있어요.\n타임테이블과 라이브 보드는 로그인 없이도 볼 수 있어요.")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .multilineTextAlignment(.center)
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP20
    )
  }

  /// 소셜 로그인 버튼과 건너뛰기. 건너뛰기는 로그인 시트의 닫기와 같은 동작이다.
  @ViewBuilder
  func actions() -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      if let message = store.visibleMessage {
        Text(message)
          .festiCoreFont(.baseFootnoteMedium)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .multilineTextAlignment(.center)
      }
      FCLoginButton(.apple) { send(.signInTapped(.apple)) }
      FCLoginButton(.google) { send(.signInTapped(.google)) }
      Button("지금은 건너뛸게요") { send(.closeTapped) }
        .festiCoreFont(.baseFootnoteMedium)
        .festiCoreLineBox(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .buttonStyle(.plain)
        .padding(
          .top,
          FestiCoreSpacing.paddingP4
        )
        .accessibilityIdentifier("launchLogin.skip")
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .top,
      FestiCoreSpacing.paddingP12
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP20
    )
    .disabled(store.isSigningIn)
  }
}

#Preview {
  LaunchLoginView(store: Store(initialState: LoginFeature.State()) { LoginFeature() })
}
