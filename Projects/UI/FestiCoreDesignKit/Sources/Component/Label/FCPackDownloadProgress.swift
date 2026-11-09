//
//  FCPackDownloadProgress.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 11/9/26.
//

import SwiftUI

/// 팩 받는 중 진행 바와 문구(Figma S00 카드의 '팩 받는 중 · 62%').
/// 실측한 진행률이 없으면 움직이는 막대만 보인다.
public struct FCPackDownloadProgress: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var text: String
  private var progress: Double?

  public init(_ text: String) {
    self.text = text
  }

  public var body: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      bar
      Text(text)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
    }
    .accessibilityElement(children: .combine)
  }
}

private extension FCPackDownloadProgress {
  @ViewBuilder
  var bar: some View {
    if let progress {
      Capsule()
        .fill(FestiCoreSemanticColor.fillStrong.color)
        .frame(height: Metric.height)
        .overlay(alignment: .leading) {
          GeometryReader { proxy in
            Capsule()
              .fill(FestiCoreSemanticColor.staticLime.color)
              .frame(width: proxy.size.width * min(
                max(
                  progress,
                  0
                ),
                1
              ))
              .animation(
                reduceMotion ? nil : .easeOut(duration: 0.3),
                value: progress
              )
          }
        }
        .accessibilityHidden(true)
    } else {
      ProgressView()
        .progressViewStyle(.linear)
        .tint(FestiCoreSemanticColor.staticLime.color)
        .accessibilityHidden(true)
    }
  }
}

// MARK: - 체이닝 설정

public extension FCPackDownloadProgress {
  /// 실측한 0...1 진행률. nil이면 진행 중 표시만 한다.
  func progress(_ progress: Double?) -> Self {
    var copy = self
    copy.progress = progress
    return copy
  }
}

private extension FCPackDownloadProgress {
  enum Metric {
    static let height: CGFloat = 6
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP20) {
    FCPackDownloadProgress("팩 받는 중 · 62%")
      .progress(0.62)
    FCPackDownloadProgress("팩 받는 중")
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
