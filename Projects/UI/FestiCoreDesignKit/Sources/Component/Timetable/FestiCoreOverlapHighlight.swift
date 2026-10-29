//
//  FestiCoreOverlapHighlight.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 내 일정끼리 겹치는 시간 구간 띠. 셋 블록 뒤 바탕에 깐다. 크기는 부모가 정한다.
public struct FestiCoreOverlapHighlight: View {
  public init() {}

  public var body: some View {
    FestiCoreSemanticColor.accentPointOrange.color
      .opacity(Metric.opacity)
      .accessibilityHidden(true)
  }
}

private extension FestiCoreOverlapHighlight {
  enum Metric {
    static let opacity: Double = 0.2
  }
}
