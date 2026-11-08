//
//  BearerChoiceTile.swift
//  Bearer
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreDesignKit
import SwiftUI

/// Figma S09 B·C Choice Tile. 존은 가로 한 줄(44pt), 활동은 아이콘 위 큰 글자(96pt)로 그린다.
struct BearerChoiceTile: View {
  enum Size: Equatable {
    case zone
    case activity
  }

  private let title: String
  private let icon: ImageAsset
  private let action: () -> Void
  private var size: Size = .zone
  private var isSelected = false

  init(
    _ title: String,
    icon: ImageAsset,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.icon = icon
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      content
        .foregroundStyle(foreground)
        .background(
          background,
          in: shape
        )
        .overlay {
          if !isSelected {
            shape.strokeBorder(
              FestiCoreSemanticColor.lineNormal.color,
              lineWidth: Metric.borderWidth
            )
          }
        }
        .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private extension BearerChoiceTile {
  @ViewBuilder
  var content: some View {
    switch size {
    case .zone:
      HStack(spacing: FestiCoreSpacing.marginM6) {
        iconImage(Metric.zoneIconSize)
        Text(title)
          .festiCoreFont(.baseFootnoteMedium)
          .festiCoreLineBox(.baseFootnoteMedium)
          .lineLimit(1)
          .minimumScaleFactor(Metric.minimumScale)
        Spacer(minLength: .zero)
      }
      .padding(FestiCoreSpacing.paddingP12)
      .frame(
        maxWidth: .infinity,
        minHeight: Metric.zoneHeight
      )
    case .activity:
      VStack(spacing: FestiCoreSpacing.marginM8) {
        iconImage(Metric.activityIconSize)
        Text(title)
          .festiCoreFont(.baseTitle2Bold)
          .festiCoreLineBox(.baseTitle2Bold)
          .lineLimit(1)
      }
      .padding(FestiCoreSpacing.paddingP16)
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity
      )
    }
  }

  func iconImage(_ side: CGFloat) -> some View {
    return Image(asset: icon)
      .resizable()
      .frame(
        width: side,
        height: side
      )
      .accessibilityHidden(true)
  }

  var shape: RoundedRectangle {
    return RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
  }

  var foreground: Color {
    return isSelected ? FestiCoreSemanticColor.inverseLabel.color : FestiCoreSemanticColor.labelNormal.color
  }

  var background: Color {
    return isSelected ? FestiCoreSemanticColor.inverseBackground.color : FestiCoreSemanticColor.backgroundElevated.color
  }

  enum Metric {
    static let zoneHeight: CGFloat = 44
    static let zoneIconSize: CGFloat = 16
    static let activityIconSize: CGFloat = 24
    static let borderWidth: CGFloat = 1
    static let minimumScale: CGFloat = 0.85
  }
}

// MARK: - 체이닝 설정

extension BearerChoiceTile {
  /// 존·활동 크기를 바꾼 사본을 돌려준다.
  func size(_ size: Size) -> Self {
    var copy = self
    copy.size = size
    return copy
  }

  /// 선택 상태를 바꾼 사본을 돌려준다.
  func isSelected(_ isSelected: Bool) -> Self {
    var copy = self
    copy.isSelected = isSelected
    return copy
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.marginM12) {
    BearerChoiceTile(
      "리벳 스테이지 앞 왼쪽",
      icon: .locationDot16
    ) {}
      .isSelected(true)
    BearerChoiceTile(
      "슬램",
      icon: .users24
    ) {}
      .size(.activity)
      .frame(height: 96)
  }
  .padding(FestiCoreSpacing.paddingP16)
  .background(FestiCoreSemanticColor.backgroundElevated.color)
  .environment(
    \.colorScheme,
    .dark
  )
}
