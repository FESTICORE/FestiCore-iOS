//
//  TimetableUnpublishedView.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI
import TimetableDomainInterface

/// 시간표 공개 전 안내와 날짜별 라인업
struct TimetableUnpublishedView: View {
  let lineup: [TimetableLineupDay]
  let notificationStatus: TimetableFeature.NotificationStatus
  let onNotify: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
        FCEmptyCard(
          icon: .bell,
          title: "축제 팩 업데이트 알림을 받아보세요",
          message: notificationMessage
        )
        .action(
          FCCardAction(
            notificationStatus == .saving ? "설정 중" : "팩 업데이트 알림 받기",
            style: .primary,
            action: { if notificationStatus != .saving { onNotify() } }
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
  var notificationMessage: String {
    switch notificationStatus {
    case .idle: return "공개된 라인업을 먼저 확인할 수 있어요.\n시간표 등 축제 팩 정보가 업데이트되면 알림을 받아보세요."
    case .saving: return "알림 설정을 저장하고 있어요."
    case .enabled: return "팩 업데이트 알림을 켰어요."
    case .permissionRequired: return "팩 업데이트 알림을 켰어요. 기기 설정에서도 알림을 허용해 주세요."
    case .failed: return "알림 설정을 저장하지 못했어요. 다시 시도해 주세요."
    }
  }


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
