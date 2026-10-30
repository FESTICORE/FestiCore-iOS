//
//  FCRecentKeyword.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 최근 검색어 칩. 칩을 누르면 다시 검색하고 x는 그 검색어만 지운다.
public struct FCRecentKeyword: View {
  private var keyword: String
  private var onSelect: () -> Void
  private var onDelete: () -> Void

  public init(_ keyword: String, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
    self.keyword = keyword
    self.onSelect = onSelect
    self.onDelete = onDelete
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP4) {
      Button(action: onSelect) {
        Text(keyword)
          .festiCoreFont(.baseFootnoteMedium)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .lineLimit(1)
      }
      .buttonStyle(.plain)
      Button(action: onDelete) {
        Image(asset: .xmark16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(keyword) 삭제")
    }
    .padding(.vertical, FestiCoreSpacing.marginM6)
    .padding(.leading, FestiCoreSpacing.paddingP12)
    .padding(.trailing, FestiCoreSpacing.paddingP8)
    .background(FestiCoreSemanticColor.fillStrong.color, in: Capsule())
  }
}

private extension FCRecentKeyword {
  enum Metric {
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  FCRecentKeyword("펜타포트", onSelect: {}, onDelete: {})
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
