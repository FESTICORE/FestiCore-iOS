//
//  FCBearerPrompt.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 더보기 맨 위 기수 진입 배너. 모드와 관계없이 라임(브랜드 포인트)이며 누르면 기수 인증 코드로 이동한다.
public struct FCBearerPrompt: View {
  private var title: String
  private var sub: String
  private var action: () -> Void

  public init(
    title: String = "기수이신가요?",
    sub: String = "운영팀에게 받은 코드로 깃발을 올려 보세요",
    action: @escaping () -> Void
  ) {
    self.title = title
    self.sub = sub
    self.action = action
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        Image(asset: .flag16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.accentPointLime.color)
          .frame(width: Metric.flagSize, height: Metric.flagSize)
          .background(FestiCoreSemanticColor.staticInk.color, in: Circle())
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM2) {
          Text(title)
            .festiCoreFont(.baseSubheadlineBold)
          Text(sub)
            .festiCoreFont(.baseCaption1Medium)
            .opacity(Metric.subOpacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        Image(asset: .chevronRight16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .accessibilityHidden(true)
      }
      .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
      .padding(.vertical, FestiCoreSpacing.paddingP12)
      .padding(.leading, FestiCoreSpacing.paddingP12)
      .padding(.trailing, FestiCoreSpacing.paddingP16)
      .background(FestiCoreSemanticColor.accentPointLime.color, in: shape)
      .contentShape(shape)
    }
    .buttonStyle(.plain)
  }
}

private extension FCBearerPrompt {
  enum Metric {
    static let flagSize: CGFloat = 36
    static let iconSize: CGFloat = 16
    static let subOpacity: Double = 0.72
  }
}

#Preview {
  FCBearerPrompt {}
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
