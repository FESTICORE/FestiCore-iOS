//
//  FCFlagNowCard.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 깃발 상세의 "지금" 카드. muted는 쉬는 중이라 흐리게, ended는 오늘 활동 종료 문구만 보인다.
public struct FCFlagNowCard: View {
  public enum State {
    case active(zone: String, activity: String, source: String)
    case muted(zone: String, activity: String, source: String)
    case ended(String = "오늘 활동을 마쳤어요")
  }

  private var state: State
  private(set) var label = "지금"
  private(set) var onZoneTap: () -> Void = {}

  public init(_ state: State) {
    self.state = state
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      Text(label)
        .festiCoreFont(.baseCaption1Medium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      switch state {
      case let .active(zone, activity, source):
        content(
          zone: zone,
          activity: activity,
          source: source,
          isMuted: false
        )
      case let .muted(zone, activity, source):
        content(
          zone: zone,
          activity: activity,
          source: source,
          isMuted: true
        )
      case let .ended(text):
        Text(text)
          .festiCoreFont(.baseCalloutMedium)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }

}

private extension FCFlagNowCard {
  @ViewBuilder
  func content(
    zone: String,
    activity: String,
    source: String,
    isMuted: Bool
  ) -> some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      FCZoneChip(
        zone,
        action: onZoneTap
      )
      .opacity(isMuted ? Metric.mutedOpacity : 1)
      Text(activity)
        .festiCoreFont(.baseBodyBold)
        .foregroundStyle(isMuted ? FestiCoreSemanticColor.labelAssistive.color : FestiCoreSemanticColor.labelNormal.color)
    }
    Text(source)
      .festiCoreFont(.baseCaption1Regular)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }
}

// MARK: - 체이닝 설정

public extension FCFlagNowCard {
  /// 위 라벨을 바꾼 사본을 돌려준다.
  func label(_ label: String) -> Self {
    var copy = self
    copy.label = label
    return copy
  }

  /// 존 칩을 눌렀을 때 동작을 바꾼 사본을 돌려준다.
  func onZoneTap(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.onZoneTap = action
    return copy
  }
}

private extension FCFlagNowCard {
  enum Metric {
    static let mutedOpacity: Double = 0.5
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCFlagNowCard(.active(zone: "리벳 앞 왼쪽", activity: "슬램", source: "기수가 4분 전에 알렸어요"))
    FCFlagNowCard(.muted(zone: "리벳 앞 왼쪽", activity: "슬램", source: "기수가 4분 전에 알렸어요"))
    FCFlagNowCard(.ended())
  }
  .padding(FestiCoreSpacing.paddingP16)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
