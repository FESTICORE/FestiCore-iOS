//
//  LabelStatusView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct LabelStatusView: View {
  var body: some View {
    DemoPage("04 Labels & Status 검증") {
      DemoSection("Tag (neutral · secondary · lime · warning · onImage)") {
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          FCTag("슬램")
          FCTag("슬램").tone(.secondary)
          FCTag("슬램").tone(.lime)
          FCTag("슬램").tone(.warning)
          FCTag("슬램").tone(.onImage)
            .padding(FestiCoreSpacing.paddingP4)
            .background(FestiCoreSemanticColor.staticalphaBlack80.color)
        }
      }
      DemoSection("Status Chip") {
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          FCStatusChip(.active)
          FCStatusChip(.resting)
          FCStatusChip(.scheduled)
          FCStatusChip(.endedToday)
        }
      }
      DemoSection("Zone Chip · Live Badge · Live Pulse · Badge") {
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          FCZoneChip("리벳 앞 왼쪽") {}
          FCLiveBadge(.now)
          FCLiveBadge(.next)
          FCLivePulse()
          FCBadge(count: 3)
          FCBadge(count: 12)
        }
      }
      DemoSection("Offline Badge · Source Line") {
        FCOfflineBadge("오프라인 · 3분 전 정보")
        FCSourceLine("출처: 주최측 공지 · 확인 10/16 14:00")
      }
      DemoSection("Bearer Footer (default · queued)") {
        FCBearerFooter()
        FCBearerFooter(queuedCount: 1)
      }
      DemoSection("Checklist Progress") {
        FCChecklistProgress(
          checked: 3,
          total: 7
        )
      }
    }
  }
}

#Preview {
  NavigationStack {
    LabelStatusView()
  }
}
