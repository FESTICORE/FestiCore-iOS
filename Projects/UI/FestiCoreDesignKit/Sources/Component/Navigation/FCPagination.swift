//
//  FCPagination.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/31/26.
//

import SwiftUI

/// 온보딩 페이지 점. 현재 페이지는 라임, 나머지는 흰색 20%. 다크 배경 전용.
public struct FCPagination: View {
  private var count: Int
  private var current: Int

  /// - Parameters:
  ///   - count: 점 개수. 1보다 작으면 아무것도 그리지 않는다.
  ///   - current: 현재 페이지. 1부터 센다.
  public init(
    count: Int = 4,
    current: Int
  ) {
    self.count = count
    self.current = current
  }

  public var body: some View {
    if let accessibilityText {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        ForEach(Array(dotStates.enumerated()), id: \.offset) { _, isCurrent in
          dot(isCurrent: isCurrent)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("페이지")
      .accessibilityValue(accessibilityText)
    }
  }
}

extension FCPagination {
  /// `1...count` 로 보정한 현재 페이지.
  var resolvedCurrent: Int {
    min(max(1, current), count)
  }

  /// 점마다 현재 페이지인지. 개수가 1보다 작으면 비어 있다.
  var dotStates: [Bool] {
    guard count >= 1 else { return [] }
    return (1 ... count).map { $0 == resolvedCurrent }
  }

  /// 보정한 페이지로 만든 접근성 값. 개수가 1보다 작으면 `nil` 이고 요소를 만들지 않는다.
  var accessibilityText: String? {
    guard count >= 1 else { return nil }
    return "페이지 \(resolvedCurrent)/\(count)"
  }

  private func dot(isCurrent: Bool) -> some View {
    Circle()
      .fill(
        isCurrent
          ? FestiCoreSemanticColor.accentPointLime.color
          : FestiCoreSemanticColor.staticalphaWhite20.color
      )
      .frame(width: Metric.dotSize, height: Metric.dotSize)
  }
}

private enum Metric {
  static let dotSize: CGFloat = 8
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    ForEach(1 ... 4, id: \.self) { page in
      FCPagination(current: page)
    }
  }
  .padding(FestiCoreSpacing.paddingP24)
  .background(FestiCoreSemanticColor.staticInk.color)
}
