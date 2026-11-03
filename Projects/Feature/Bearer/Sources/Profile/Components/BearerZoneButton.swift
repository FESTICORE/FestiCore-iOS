//
//  BearerZoneButton.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 존 하나를 고르는 칸. 고르면 Inverse로 칠한다. 깃발 프로필과 기수 보드 존 시트가 같이 쓴다.
struct BearerZoneButton: View {
  let name: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.marginM8) {
        Image(asset: .locationDot16)
          .resizable()
          .frame(width: 14, height: 14)
          .accessibilityHidden(true)
        Text(name)
          .festiCoreFont(.baseSubheadlineMedium)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        Spacer(minLength: 0)
      }
      .foregroundStyle(foreground)
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .frame(maxWidth: .infinity, minHeight: 56)
      .background(background, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      .overlay {
        if !isSelected {
          RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
            .strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: 1)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private extension BearerZoneButton {
  var foreground: Color {
    isSelected ? FestiCoreSemanticColor.inverseLabel.color : FestiCoreSemanticColor.labelNormal.color
  }

  var background: Color {
    isSelected ? FestiCoreSemanticColor.inverseBackground.color : FestiCoreSemanticColor.backgroundNormal.color
  }
}
