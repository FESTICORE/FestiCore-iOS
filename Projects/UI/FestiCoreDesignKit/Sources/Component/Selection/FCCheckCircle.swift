//
//  FCCheckCircle.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 원형 체크. 편집 모드 선택, 신고 사유, 약관 체크에 쓰며 checked는 Static/Lime 바탕과 Static/Ink 체크다.
public struct FCCheckCircle: View {
  private var isChecked: Bool
  private(set) var iconSize: CGFloat = Metric.iconSize

  public init(isChecked: Bool) {
    self.isChecked = isChecked
  }

  public var body: some View {
    ZStack {
      if isChecked {
        Circle()
          .fill(FestiCoreSemanticColor.staticLime.color)
        Image(asset: .check)
          .resizable()
          .frame(width: iconSize, height: iconSize)
          .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
      } else {
        Circle()
          .strokeBorder(FestiCoreSemanticColor.lineStrong.color, lineWidth: Metric.borderWidth)
      }
    }
    .frame(width: Metric.size, height: Metric.size)
    .accessibilityHidden(true)
  }
}

// MARK: - 체이닝 설정

public extension FCCheckCircle {
  /// 체크 아이콘 크기를 바꾼 사본을 돌려준다. 체크리스트는 14를 쓴다.
  func iconSize(_ iconSize: CGFloat) -> Self {
    var copy = self
    copy.iconSize = iconSize
    return copy
  }
}

private extension FCCheckCircle {
  enum Metric {
    static let size: CGFloat = 24
    static let iconSize: CGFloat = 16
    static let borderWidth: CGFloat = 1.5
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP16) {
    FCCheckCircle(isChecked: true)
    FCCheckCircle(isChecked: false)
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
