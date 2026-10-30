//
//  FCStageRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 지금·다음 무대 한 줄. 내 일정이면 라임 바탕과 태그를 표시한다.
public struct FCStageRow: View {
  /// 무대 한쪽(지금 또는 다음)의 아티스트와 시간.
  public struct Slot: Sendable {
    public var artist: String
    public var time: String

    public init(
      artist: String,
      time: String
    ) {
      self.artist = artist
      self.time = time
    }
  }

  private var stage: String
  private var now: Slot
  private var next: Slot
  private(set) var isMine = false

  public init(
    stage: String,
    now: Slot,
    next: Slot
  ) {
    self.stage = stage
    self.now = now
    self.next = next
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Text(stage)
          .festiCoreFont(.baseFootnoteBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .frame(maxWidth: .infinity, alignment: .leading)
        if isMine {
          FCTag("내 일정")
            .tone(.lime)
        }
      }
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        slot(
          now,
          kind: .now
        )
        Image(asset: .chevronRight16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .accessibilityHidden(true)
        slot(
          next,
          kind: .next
        )
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .background(isMine ? FestiCoreSemanticColor.accentBackgroundLime.color : .clear)
    .accessibilityElement(children: .combine)
  }

  private func slot(
    _ slot: Slot,
    kind: FCLiveBadge.Kind
  ) -> some View {
    HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
      FCLiveBadge(kind)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(slot.artist)
          .festiCoreFont(kind == .now ? .baseBodyBold : .baseCalloutMedium)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(slot.time)
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - 체이닝 설정

public extension FCStageRow {
  /// 내 일정 여부를 바꾼 사본을 돌려준다.
  func isMine(_ isMine: Bool) -> Self {
    var copy = self
    copy.isMine = isMine
    return copy
  }
}

private extension FCStageRow {
  enum Metric {
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCStageRow(
      stage: "리벳 스테이지",
      now: .init(
        artist: "스모킹구스",
        time: "15:28 종료"
      ),
      next: .init(
        artist: "노이즈캔디",
        time: "15:40 시작"
      )
    )
    .isMine(true)
    FCStageRow(
      stage: "리벳 스테이지",
      now: .init(
        artist: "스모킹구스",
        time: "15:28 종료"
      ),
      next: .init(
        artist: "노이즈캔디",
        time: "15:40 시작"
      )
    )
  }
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
