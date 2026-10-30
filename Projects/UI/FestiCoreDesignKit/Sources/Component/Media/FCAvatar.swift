//
//  FCAvatar.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 프로필 이니셜. 가입할 때 색 8종 중 하나를 무작위로 정하고, gray는 기본값이다.
public struct FCAvatar: View {
  public enum Tint: CaseIterable, Sendable {
    case gray
    case lime
    case purple
    case red
    case orange
    case green
    case blue
    case pink
    case yellow
  }

  private var initial: String
  private(set) var tint: Tint = .gray

  public init(_ initial: String) {
    self.initial = initial
  }

  public var body: some View {
    Text(initial.prefix(1))
      .festiCoreFont(.baseSubheadlineBold)
      .foregroundStyle(colors.foreground.color)
      .frame(width: Metric.size, height: Metric.size)
      .background(colors.background.color, in: Circle())
      .accessibilityHidden(true)
  }

  private var colors: (background: FestiCoreSemanticColor, foreground: FestiCoreSemanticColor) {
    switch tint {
    case .gray: return (.fillStrong, .labelNeutral)
    case .lime: return (.accentBackgroundLime, .accentForegroundLime)
    case .purple: return (.accentBackgroundPurple, .accentForegroundPurple)
    case .red: return (.accentBackgroundRed, .accentForegroundRed)
    case .orange: return (.accentBackgroundOrange, .accentForegroundOrange)
    case .green: return (.accentBackgroundGreen, .accentForegroundGreen)
    case .blue: return (.accentBackgroundBlue, .accentForegroundBlue)
    case .pink: return (.accentBackgroundPink, .accentForegroundPink)
    case .yellow: return (.accentBackgroundYellow, .accentForegroundYellow)
    }
  }
}

// MARK: - 체이닝 설정

public extension FCAvatar {
  /// 색을 바꾼 사본을 돌려준다.
  func tint(_ tint: Tint) -> Self {
    var copy = self
    copy.tint = tint
    return copy
  }
}

private extension FCAvatar {
  enum Metric {
    static let size: CGFloat = 40
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP12) {
    ForEach(FCAvatar.Tint.allCases, id: \.self) { tint in
      FCAvatar("민").tint(tint)
    }
  }
  .padding(FestiCoreSpacing.paddingP12)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
