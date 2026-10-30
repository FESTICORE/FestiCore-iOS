//
//  FCStatusChip.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 깃발 상태 칩. 항상 점과 단어를 함께 표시한다.
public struct FCStatusChip: View {
  public enum Status: Sendable {
    case active
    case resting
    case scheduled
    case endedToday

    var title: String {
      switch self {
      case .active: return "활동 중"
      case .resting: return "쉬는 중"
      case .scheduled: return "예정"
      case .endedToday: return "오늘 종료"
      }
    }
  }

  private var status: Status

  public init(_ status: Status) {
    self.status = status
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      dot
      Text(status.title)
        .festiCoreFont(.baseCaption1Medium)
        .foregroundStyle(foregroundColor.color)
        .lineLimit(1)
    }
    .padding(.vertical, FestiCoreSpacing.paddingP4)
    .padding(.horizontal, FestiCoreSpacing.paddingP8)
    .background(backgroundColor.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r8))
  }

}

private extension FCStatusChip {
  @ViewBuilder
  var dot: some View {
    if status == .scheduled {
      Circle()
        .strokeBorder(FestiCoreSemanticColor.accentForegroundOrange.color, lineWidth: Metric.dotBorderWidth)
        .frame(width: Metric.dotSize, height: Metric.dotSize)
    } else {
      Circle()
        .fill(status == .endedToday ? FestiCoreSemanticColor.lineStrong.color : foregroundColor.color)
        .frame(width: Metric.dotSize, height: Metric.dotSize)
    }
  }

  private var backgroundColor: FestiCoreSemanticColor {
    switch status {
    case .active: return .accentBackgroundPurple
    case .resting: return .accentBackgroundGreen
    case .scheduled: return .accentBackgroundOrange
    case .endedToday: return .fillNormal
    }
  }

  private var foregroundColor: FestiCoreSemanticColor {
    switch status {
    case .active: return .accentForegroundPurple
    case .resting: return .accentForegroundGreen
    case .scheduled: return .accentForegroundOrange
    case .endedToday: return .labelAssistive
    }
  }
}

private extension FCStatusChip {
  enum Metric {
    static let dotSize: CGFloat = 6
    static let dotBorderWidth: CGFloat = 1
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP12) {
    FCStatusChip(.active)
    FCStatusChip(.resting)
    FCStatusChip(.scheduled)
    FCStatusChip(.endedToday)
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
