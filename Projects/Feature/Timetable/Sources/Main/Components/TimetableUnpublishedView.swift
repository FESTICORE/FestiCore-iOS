//
//  TimetableUnpublishedView.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 시간표 공개 전 안내와 날짜별 라인업
struct TimetableUnpublishedView: View {
  let lineup: [TimetableLineupDay]
  let onNotify: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
        FCEmptyCard(
          icon: .bell,
          title: "시간표가 공개되면 알려 드릴게요",
          message: "대략적인 라인업은 먼저 확인할 수 있어요.\n시간표 공개 후 원하는 무대를 선택해 내 일정에 넣어 보세요."
        )
        .action(
          FCCardAction(
            "알림 받기",
            style: .primary,
            action: onNotify
          )
        )
        ForEach(lineup) { day in
          section(day)
        }
      }
      .padding(FestiCoreSpacing.paddingP16)
    }
  }
}

private extension TimetableUnpublishedView {
  func section(_ day: TimetableLineupDay) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Text(day.title)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .accessibilityAddTraits(.isHeader)
      VStack(spacing: .zero) {
        ForEach(Array(day.artists.enumerated()), id: \.offset) { index, artist in
          FCLineupRow(
            number: String(format: "%02d", index + 1),
            artist: artist
          )
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }
}
