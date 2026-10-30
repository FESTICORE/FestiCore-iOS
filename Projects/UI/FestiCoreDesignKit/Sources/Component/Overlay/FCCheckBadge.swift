//
//  FCCheckBadge.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 완료·확인 화면에 쓰는 라임 원 + 체크 표시
struct FCCheckBadge: View {
  var body: some View {
    CheckMark()
      .stroke(
        FestiCoreSemanticColor.staticInk.color,
        style: StrokeStyle(
          lineWidth: Metric.lineWidth,
          lineCap: .round,
          lineJoin: .round
        )
      )
      .frame(width: Metric.markWidth, height: Metric.markHeight)
      .frame(width: Metric.size, height: Metric.size)
      .background(FestiCoreSemanticColor.staticLime.color, in: Circle())
      .accessibilityHidden(true)
  }
}

private struct CheckMark: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.width * 0.36, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    return path
  }
}

private enum Metric {
  static let size: CGFloat = 96
  static let markWidth: CGFloat = 44
  static let markHeight: CGFloat = 31
  static let lineWidth: CGFloat = 8
}

#Preview {
  FCCheckBadge()
    .padding(FestiCoreSpacing.paddingP24)
}
