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
      // Figma S10 Choice Tile(zone): 아이콘 16, 간격 6
      HStack(spacing: FestiCoreSpacing.marginM6) {
        Image(asset: .locationDot16)
          .resizable()
          .frame(
            width: 16,
            height: 16
          )
          .accessibilityHidden(true)
        // Figma S10 존 버튼: 높이 44, 13pt(긴 존 이름도 한 줄에 다 보인다)
        Text(name)
          .festiCoreFont(.baseFootnoteMedium)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        Spacer(minLength: 0)
      }
      .foregroundStyle(foreground)
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP12
      )
      .frame(
        maxWidth: .infinity,
        minHeight: 44
      )
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
