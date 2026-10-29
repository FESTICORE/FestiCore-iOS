//
//  FestiCoreStageHeader.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 무대 컬럼 머리. 점 색 = 무대 색.
public struct FestiCoreStageHeader: View {
  private var name: String
  private(set) var dotColor: FestiCoreSemanticColor = .accentPointLime

  public init(name: String) {
    self.name = name
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.marginM6) {
      Circle()
        .fill(dotColor.color)
        .frame(width: Metric.dotSize, height: Metric.dotSize)
        .accessibilityHidden(true)
      Text(name)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .frame(height: Metric.height)
    .accessibilityAddTraits(.isHeader)
  }
}

// MARK: - 체이닝 설정
public extension FestiCoreStageHeader {
  /// `dotColor` 를 바꾼 사본을 돌려준다.
  func dotColor(_ color: FestiCoreSemanticColor) -> Self {
    var copy = self
    copy.dotColor = color
    return copy
  }
}

private extension FestiCoreStageHeader {
  enum Metric {
    static let height: CGFloat = 40
    static let dotSize: CGFloat = 8
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FestiCoreStageHeader(name: "메인 스테이지")
    FestiCoreStageHeader(name: "서브 스테이지")
      .dotColor(.accentPointOrange)
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
