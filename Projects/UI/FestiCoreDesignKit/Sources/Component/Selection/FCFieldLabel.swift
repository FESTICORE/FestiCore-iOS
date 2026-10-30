//
//  FCFieldLabel.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 칩·타일 같은 선택 묶음 위 라벨. `FCTextField` 라벨 줄과 같은 규격이다.
public struct FCFieldLabel: View {
  private var label: String
  private(set) var counter: String?

  public init(_ label: String) {
    self.label = label
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Text(label)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let counter {
        Text(counter)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .monospacedDigit()
      }
    }
    .lineLimit(1)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - 체이닝 설정

public extension FCFieldLabel {
  /// 오른쪽 카운터 글자를 바꾼 사본을 돌려준다. `nil`이면 숨긴다.
  func counter(_ counter: String?) -> Self {
    var copy = self
    copy.counter = counter
    return copy
  }
}

#Preview {
  FCFieldLabel("성향 태그")
    .counter("0 / 3")
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
