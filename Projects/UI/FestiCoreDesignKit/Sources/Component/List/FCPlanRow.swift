//
//  FCPlanRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 깃발 오늘 계획 한 줄. now는 Live Pulse와 "공연 중"을 붙이고 past는 50%로 흐리게 보인다.
public struct FCPlanRow: View {
  public enum State: Sendable {
    case upcoming
    case now
    case past
  }

  private var time: String
  private var artist: String
  private var stage: String
  private var state: State
  private(set) var isMine = false
  private(set) var liveLabel = "공연 중"

  public init(
    time: String,
    artist: String,
    stage: String,
    state: State
  ) {
    self.time = time
    self.artist = artist
    self.stage = stage
    self.state = state
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      Group {
        if state == .now {
          FCLivePulse()
        } else {
          Color.clear
        }
      }
      .frame(width: Metric.indicatorSize, height: Metric.indicatorSize)
      Group {
        Text(time)
          .festiCoreFont(.baseCalloutBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .monospacedDigit()
          .frame(width: Metric.timeWidth, alignment: .leading)
        VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM2) {
          Text(artist)
            .festiCoreFont(.baseCalloutMedium)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          HStack(spacing: FestiCoreSpacing.paddingP4) {
            Text(stage)
              .festiCoreFont(.baseCaption1Regular)
              .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            if state == .now {
              Text("· \(liveLabel)")
                .festiCoreFont(.baseCaption1Bold)
                .foregroundStyle(FestiCoreSemanticColor.secondaryNormal.color)
            }
          }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        if isMine {
          FCTag("내 일정")
            .tone(.lime)
        }
      }
      .opacity(state == .past ? Metric.pastOpacity : 1)
    }
    .padding(.vertical, Metric.verticalPadding)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - 체이닝 설정

public extension FCPlanRow {
  /// 내 일정 여부를 바꾼 사본을 돌려준다.
  func isMine(_ isMine: Bool) -> Self {
    var copy = self
    copy.isMine = isMine
    return copy
  }

  /// 공연 중 표시 글자를 바꾼 사본을 돌려준다.
  func liveLabel(_ liveLabel: String) -> Self {
    var copy = self
    copy.liveLabel = liveLabel
    return copy
  }
}

private extension FCPlanRow {
  enum Metric {
    static let indicatorSize: CGFloat = 16
    static let timeWidth: CGFloat = 48
    static let verticalPadding: CGFloat = 14
    static let pastOpacity: Double = 0.5
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    ForEach([FCPlanRow.State.upcoming, .now, .past], id: \.self) { state in
      FCPlanRow(
        time: "18:40",
        artist: "The Lime Flags",
        stage: "SUB 스테이지",
        state: state
      )
      .isMine(true)
    }
  }
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
