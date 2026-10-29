//
//  FCStepHeader.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 준비 안내 맨 위. 진행 막대 + "나중에 할게요".
public struct FCStepHeader: View {
  private var step: Int
  private var total: Int
  private(set) var laterTitle = "나중에 할게요"
  private(set) var laterAction: (() -> Void)?

  public init(step: Int, total: Int = 3) {
    self.step = step
    self.total = total
  }

  public var body: some View {
    HStack(spacing: .zero) {
      HStack(spacing: FestiCoreSpacing.paddingP4) {
        ForEach(0..<resolvedTotal, id: \.self) { index in
          RoundedRectangle(cornerRadius: Metric.barRadius)
            .fill(
              index < resolvedStep
                ? FestiCoreSemanticColor.labelNormal.color
                : FestiCoreSemanticColor.fillStrong.color
            )
            .frame(width: Metric.barWidth, height: Metric.barHeight)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityLabel)

      Spacer(minLength: .zero)

      if let laterAction {
        Button(action: laterAction) {
          Text(laterTitle)
            .festiCoreFont(.baseFootnoteMedium)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .frame(height: Metric.height)
  }

  /// 최소 1단계.
  var resolvedTotal: Int { max(1, total) }

  /// `0...resolvedTotal` 로 보정한 현재 단계.
  var resolvedStep: Int { min(max(0, step), resolvedTotal) }

  var accessibilityLabel: String { "\(resolvedStep)/\(resolvedTotal)단계" }
}

// MARK: - 체이닝 설정
public extension FCStepHeader {
  /// `step` 을 바꾼 사본을 돌려준다.
  func step(_ step: Int) -> Self {
    var copy = self
    copy.step = step
    return copy
  }

  /// "나중에 할게요" 버튼을 지정한 사본을 돌려준다. 지정하지 않으면 버튼을 그리지 않는다.
  func onLater(title: String = "나중에 할게요", _ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.laterTitle = title
    copy.laterAction = action
    return copy
  }
}

private extension FCStepHeader {
  enum Metric {
    static let height: CGFloat = 44
    static let barWidth: CGFloat = 28
    static let barHeight: CGFloat = 4
    static let barRadius: CGFloat = 2
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCStepHeader(step: 1)
    FCStepHeader(step: 2)
      .onLater {}
    FCStepHeader(step: 3)
  }
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
