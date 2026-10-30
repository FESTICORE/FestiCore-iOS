//
//  FCLivePulse.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 지금 공연 중 불빛(Secondary). 바깥 링이 1.2초 주기로 일렁이며 "공연 중" 글자와 함께 쓴다.
public struct FCLivePulse: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isExpanded = false

  public init() {}

  public var body: some View {
    let color = FestiCoreSemanticColor.secondaryNormal.color
    ZStack {
      Circle()
        .fill(color.opacity(Metric.outerOpacity))
        .frame(width: Metric.outerSize, height: Metric.outerSize)
        .scaleEffect(isExpanded ? 1 : Metric.collapsedScale)
      Circle()
        .fill(color.opacity(Metric.innerOpacity))
        .frame(width: Metric.innerSize, height: Metric.innerSize)
      Circle()
        .fill(color)
        .frame(width: Metric.dotSize, height: Metric.dotSize)
    }
    .frame(width: Metric.outerSize, height: Metric.outerSize)
    .accessibilityHidden(true)
    .onAppear {
      guard !reduceMotion else {
        isExpanded = true
        return
      }
      withAnimation(.easeInOut(duration: Metric.period / 2).repeatForever(autoreverses: true)) {
        isExpanded = true
      }
    }
  }
}

private extension FCLivePulse {
  enum Metric {
    static let outerSize: CGFloat = 16
    static let innerSize: CGFloat = 11
    static let dotSize: CGFloat = 6
    static let outerOpacity: Double = 0.16
    static let innerOpacity: Double = 0.32
    static let collapsedScale: CGFloat = 0.7
    static let period: Double = 1.2
  }
}

#Preview {
  FCLivePulse()
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
