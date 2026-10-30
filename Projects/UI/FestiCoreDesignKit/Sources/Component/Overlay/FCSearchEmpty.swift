//
//  FCSearchEmpty.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 검색 결과가 없을 때 보여 주는 안내
public struct FCSearchEmpty: View {
  private var query: String
  private(set) var message = "페스티벌 이름, 아티스트, 장소로 다시 찾아보세요"

  public init(query: String) {
    self.query = query
  }

  public var body: some View {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
      Image(asset: .magnifyingGlass)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .accessibilityHidden(true)
      VStack(spacing: FestiCoreSpacing.paddingP12) {
        Text("‘\(query)’ 검색 결과가 없어요")
          .festiCoreFont(.baseCalloutBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(message)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .multilineTextAlignment(.center)
    }
    .padding(.vertical, Metric.verticalPadding)
    .padding(.horizontal, FestiCoreSpacing.paddingP24)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - 체이닝 설정

public extension FCSearchEmpty {
  /// 안내 문구를 바꾼 사본을 돌려준다.
  func message(_ message: String) -> Self {
    var copy = self
    copy.message = message
    return copy
  }
}

private extension FCSearchEmpty {
  enum Metric {
    static let iconSize: CGFloat = 36
    static let verticalPadding: CGFloat = 48
  }
}

#Preview {
  FCSearchEmpty(query: "락페")
}
