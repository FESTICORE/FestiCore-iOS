//
//  BearerCodeBoxes.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 코드 6칸. 입력은 위에 겹친 투명 입력창이 받고, 칸은 글자와 현재 위치만 그린다.
struct BearerCodeBoxes: View {
  let code: String
  let length: Int
  let isFocused: Bool
  let isError: Bool
  let isDisabled: Bool

  var body: some View {
    HStack(spacing: FestiCoreSpacing.marginM8) {
      ForEach(0 ..< length, id: \.self) { index in
        box(at: index)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("코드 \(length)자리")
    .accessibilityValue(code.isEmpty ? "비어 있음" : code.map(String.init).joined(separator: " "))
  }
}

private extension BearerCodeBoxes {
  func box(at index: Int) -> some View {
    let character = character(at: index)
    let isCurrent = isFocused && !isDisabled && index == min(code.count, length - 1) && code.count < length
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    return ZStack {
      shape.fill(FestiCoreSemanticColor.fillNormal.color)
      if let character {
        Text(String(character))
          .festiCoreFont(.baseTitle3Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      } else if isCurrent {
        Rectangle()
          .fill(FestiCoreSemanticColor.labelNormal.color)
          .frame(width: 1.5, height: Metric.caretHeight)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: Metric.height)
    .overlay {
      if let color = borderColor(isCurrent: isCurrent) {
        shape.strokeBorder(color, lineWidth: Metric.borderWidth)
      }
    }
  }

  func character(at index: Int) -> Character? {
    guard index < code.count else { return nil }
    return code[code.index(code.startIndex, offsetBy: index)]
  }

  func borderColor(isCurrent: Bool) -> Color? {
    if isError { return FestiCoreSemanticColor.statusNegative.color }
    if isCurrent { return FestiCoreSemanticColor.labelNormal.color }
    return nil
  }

  enum Metric {
    static let height: CGFloat = 56
    static let caretHeight: CGFloat = 22
    static let borderWidth: CGFloat = 1.5
  }
}
