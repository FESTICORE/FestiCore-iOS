//
//  FCBanner.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 화면 안 안내 띠. 누르면 자세한 내용으로 이동한다.
public struct FCBanner: View {
  private var text: String
  private var action: () -> Void
  private(set) var icon: ImageAsset = .triangleExclamation16

  public init(
    _ text: String,
    action: @escaping () -> Void
  ) {
    self.text = text
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: icon)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .accessibilityHidden(true)
        Text(text)
          .festiCoreFont(.baseFootnoteBold)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(asset: .chevronRight16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .accessibilityHidden(true)
      }
      .foregroundStyle(FestiCoreSemanticColor.inverseLabel.color)
      .padding(.vertical, FestiCoreSpacing.paddingP12)
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .background(FestiCoreSemanticColor.inverseBackground.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
      .contentShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - 체이닝 설정

public extension FCBanner {
  /// 왼쪽 아이콘을 바꾼 사본을 돌려준다.
  func icon(_ icon: ImageAsset) -> Self {
    var copy = self
    copy.icon = icon
    return copy
  }
}

private extension FCBanner {
  enum Metric {
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  FCBanner("시간표가 바뀌었어요 · 3개 변경") {}
    .padding(FestiCoreSpacing.paddingP16)
}
