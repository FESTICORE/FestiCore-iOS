//
//  LoginView.swift
//  Login
//
//  Created by FestiCore on 11/12/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// 로그아웃 상태로 앱을 켰을 때 홈 위를 덮는 S14 A 로그인 첫 진입 화면. 로그인 시트와 같은 `LoginFeature`를 쓴다.
@ViewAction(for: LoginFeature.self)
public struct LoginView: View {
  @Bindable public var store: StoreOf<LoginFeature>
  @Environment(\.colorScheme) private var colorScheme

  public init(store: StoreOf<LoginFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      introduction()
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        )
      actions()
    }
    .overlay { decorations }
    .background(FestiCoreSemanticColor.backgroundNormal.color.ignoresSafeArea())
  }
}

private extension LoginView {
  /// 시안 기준 프레임(393×852). 장식 별 위치는 이 크기에 대한 비율로 놓는다.
  static let designSize = CGSize(
    width: 393,
    height: 852
  )

  /// 시안 Sparkles(623:24655)의 별 모양. 8각 별과 4각 반짝이 두 가지다.
  enum DecorationShape {
    case star8
    case star4

    var asset: AuthImages {
      switch self {
      case .star8: return AuthAsset.sparkleStar8
      case .star4: return AuthAsset.sparkleStar4
      }
    }
  }

  /// 시안 별 색 변수. `secondary`는 라이트에서 Secondary/Normal, 다크 프레임에서 Static/White다.
  enum DecorationTone {
    case lime
    case pink
    case purple
    case secondary
  }

  /// 시안 393×852 기준 장식 별 중심·크기·회전(도)과 색
  struct Decoration {
    let shape: DecorationShape
    let centerX: CGFloat
    let centerY: CGFloat
    let size: CGFloat
    let rotation: Double
    let tone: DecorationTone
  }

  static let decorations: [Decoration] = [
    Decoration(
      shape: .star8,
      centerX: 48,
      centerY: 96,
      size: 22,
      rotation: -100,
      tone: .lime
    ),
    Decoration(
      shape: .star4,
      centerX: 170,
      centerY: 64,
      size: 14,
      rotation: 40,
      tone: .secondary
    ),
    Decoration(
      shape: .star8,
      centerX: 300,
      centerY: 108,
      size: 26,
      rotation: 20,
      tone: .pink
    ),
    Decoration(
      shape: .star4,
      centerX: 362,
      centerY: 196,
      size: 16,
      rotation: 100,
      tone: .lime
    ),
    Decoration(
      shape: .star4,
      centerX: 34,
      centerY: 214,
      size: 16,
      rotation: -40,
      tone: .purple
    ),
    Decoration(
      shape: .star8,
      centerX: 112,
      centerY: 170,
      size: 20,
      rotation: -20,
      tone: .secondary
    ),
    Decoration(
      shape: .star4,
      centerX: 252,
      centerY: 184,
      size: 12,
      rotation: -100,
      tone: .purple
    ),
    Decoration(
      shape: .star8,
      centerX: 16,
      centerY: 336,
      size: 14,
      rotation: 40,
      tone: .lime
    ),
    Decoration(
      shape: .star8,
      centerX: 376,
      centerY: 318,
      size: 20,
      rotation: 20,
      tone: .purple
    ),
    Decoration(
      shape: .star8,
      centerX: 22,
      centerY: 470,
      size: 22,
      rotation: 100,
      tone: .pink
    ),
    Decoration(
      shape: .star4,
      centerX: 372,
      centerY: 532,
      size: 14,
      rotation: -40,
      tone: .secondary
    ),
    Decoration(
      shape: .star4,
      centerX: 70,
      centerY: 592,
      size: 18,
      rotation: -20,
      tone: .lime
    ),
    Decoration(
      shape: .star4,
      centerX: 322,
      centerY: 600,
      size: 16,
      rotation: 40,
      tone: .pink
    ),
  ]

  /// 화면 전체에 시안 비율대로 흩뿌린 장식 별. 터치와 읽기 도구에서는 숨긴다.
  var decorations: some View {
    GeometryReader { proxy in
      ForEach(
        Self.decorations.indices,
        id: \.self
      ) { index in
        let item = Self.decorations[index]
        Image(asset: item.shape.asset)
          .renderingMode(.template)
          .resizable()
          .frame(
            width: item.size,
            height: item.size
          )
          .foregroundStyle(color(for: item.tone))
          .rotationEffect(.degrees(item.rotation))
          .position(
            x: proxy.size.width * item.centerX / Self.designSize.width,
            y: proxy.size.height * item.centerY / Self.designSize.height
          )
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  func color(for tone: DecorationTone) -> Color {
    switch tone {
    case .lime: return .staticLime
    case .pink: return .accentPointPink
    case .purple: return .accentPointPurple
    case .secondary: return colorScheme == .dark ? .staticWhite : .secondaryNormal
    }
  }

  /// 시안 Logo 3D(623:24653) 이미지. 라이트·다크가 같은 이미지다.
  var logo: some View {
    return Image(asset: AuthAsset.logo3d)
      .resizable()
      .scaledToFit()
      .frame(
        width: 280,
        height: 42.44
      )
      .accessibilityLabel(Text("FestiCore"))
  }

  /// 시안 Contents: 좌우 16 안에서 로고 아래 20 간격으로 제목과 설명을 둔다.
  @ViewBuilder
  func introduction() -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP20) {
      logo
      introductionText()
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
  }

  /// 시안 601:23373·601:23374: 폭 329(Contents 안쪽에서 좌우 16 더), 제목과 설명 사이 20
  @ViewBuilder
  func introductionText() -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP20) {
      Text("가장 뜨거운 현장 속으로")
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text("로그인하면 깃발을 팔로우하고 크루를 만들 수 있어요.\n타임테이블과 라이브 보드는 로그인 없이도 볼 수 있어요")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .multilineTextAlignment(.center)
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
  }

  /// 소셜 로그인 버튼과 건너뛰기. 건너뛰기는 로그인 시트의 닫기와 같은 동작이다.
  /// 시안 Actions(601:23341): 위 12·아래 8(그 아래 홈 표시 영역), 버튼·건너뛰기 간격 12
  @ViewBuilder
  func actions() -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      if let message = store.visibleMessage {
        Text(message)
          .festiCoreFont(.baseFootnoteMedium)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .multilineTextAlignment(.center)
      }
      LoginProviderButtons(
        spacing: FestiCoreSpacing.paddingP12
      ) { send(.signInTapped($0)) }
      Button("지금은 건너뛸게요") { send(.closeTapped) }
        .festiCoreFont(.baseFootnoteMedium)
        .festiCoreLineBox(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .buttonStyle(.plain)
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
      FestiCoreSpacing.paddingP8
    )
    .disabled(store.isSigningIn)
  }
}

#Preview {
  LoginView(store: Store(initialState: LoginFeature.State()) { LoginFeature() })
}
