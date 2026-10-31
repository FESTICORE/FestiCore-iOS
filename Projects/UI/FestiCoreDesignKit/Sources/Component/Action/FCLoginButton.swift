//
//  FCLoginButton.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// Apple·Google 로그인 버튼. 각 회사 가이드를 따라 같은 크기로 나란히 두며 Google은 모드와 관계없이 흰색이다.
public struct FCLoginButton: View {
  public enum Provider: Sendable {
    case apple
    case google
  }

  private var provider: Provider
  private var action: () -> Void

  public init(
    _ provider: Provider,
    action: @escaping () -> Void
  ) {
    self.provider = provider
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        logo
        Text(provider == .apple ? "Apple로 계속" : "Google로 계속")
          .festiCoreFont(.baseCalloutBold)
          .lineLimit(1)
      }
      .foregroundStyle(provider == .apple ? FestiCoreSemanticColor.inverseLabel.color : FestiCoreSemanticColor.staticInk.color)
      .frame(maxWidth: .infinity)
      .frame(height: Metric.height)
      .background(
        provider == .apple ? FestiCoreSemanticColor.inverseBackground.color : FestiCoreSemanticColor.staticWhite.color,
        in: shape
      )
      .overlay {
        if provider == .google {
          shape.stroke(FestiCoreSemanticColor.lineStrong.color, lineWidth: Metric.borderWidth)
        }
      }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
  }

}

private extension FCLoginButton {
  @ViewBuilder
  var logo: some View {
    switch provider {
    case .apple:
      Image(asset: .appleLogo)
        .renderingMode(.template)
        .resizable()
        .frame(width: Metric.appleLogoSize.width, height: Metric.appleLogoSize.height)
        .foregroundStyle(FestiCoreSemanticColor.inverseLabel.color)
        .accessibilityHidden(true)
    case .google:
      // Google 로고는 브랜드 색을 그대로 써야 하므로 원본 렌더링을 유지한다.
      Image(asset: .googleLogo)
        .renderingMode(.original)
        .resizable()
        .frame(width: Metric.googleLogoSize, height: Metric.googleLogoSize)
        .accessibilityHidden(true)
    }
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
  }
}

private extension FCLoginButton {
  enum Metric {
    static let height: CGFloat = 52
    static let borderWidth: CGFloat = 1
    static let appleLogoSize = CGSize(width: 16, height: 18)
    static let googleLogoSize: CGFloat = 18
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP8) {
    FCLoginButton(.apple) {}
    FCLoginButton(.google) {}
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
