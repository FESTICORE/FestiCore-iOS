//
//  TimetableUnpublishedView.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI
import TimetableDomainInterface

/// 시간표 공개 전 안내와 날짜별 라인업
struct TimetableUnpublishedView: View {
  let lineup: [TimetableLineupDay]
  let notificationStatus: TimetableFeature.NotificationStatus
  let onNotify: () -> Void

  var body: some View {
    ScrollView {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP24 + FestiCoreSpacing.marginM2
      ) {
        FCEmptyCard(
          icon: .bell,
          title: "시간표가 공개되면 알려 드릴게요",
          message: notificationMessage
        )
        .action(
          FCCardAction(
            notificationStatus == .saving ? "설정 중" : "알림 받기",
            style: .primary,
            action: { if notificationStatus != .saving { onNotify() } }
          )
        )
        .padding(
          .bottom,
          FestiCoreSpacing.marginM6
        )
        .background(
          FestiCoreSemanticColor.backgroundElevated.color,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        )
        ForEach(lineup) { day in
          section(day)
        }
      }
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )
      .padding(
        .top,
        FestiCoreSpacing.paddingP16
      )
    }
    // 라인업 끝까지 스크롤해도 하단에서 20만큼 띄운다.
    .fcScrollBottomInset()
  }
}

private extension TimetableUnpublishedView {
  var notificationMessage: String {
    switch notificationStatus {
    case .idle: return "대략적인 라인업은 먼저 확인할 수 있어요.\n시간표 공개 후 원하는 무대를 선택해 내 일정에 넣어 보세요."
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
        .festiCoreLineBox(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .accessibilityAddTraits(.isHeader)
      VStack(spacing: .zero) {
        ForEach(Array(day.artists.enumerated()), id: \.offset) { index, artist in
          FCLineupRow(
            number: String(format: "%02d", index + 1),
            artist: artist.name,
            showsSeparator: index < day.artists.count - 1
          )
          .thumbnail(artist.imageURL.map {
            FCRemoteImage(url: $0)
              .content(.fill)
          })
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }
}
