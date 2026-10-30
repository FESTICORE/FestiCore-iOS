//
//  OverlayView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct OverlayView: View {
  private enum Sheet: String, Identifiable {
    case login
    case report

    var id: String {
      rawValue
    }
  }

  @State private var sheet: Sheet?
  @State private var dialog: FCDialogItem?
  @State private var toast: FCToast.Item?
  @State private var reportSelection: Int?

  var body: some View {
    DemoPage("08 Feedback & Overlay 검증") {
      DemoSection("Toast (누르면 2초 표시)") {
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          FCButton("예매") { toast = .booked() }
            .style(.secondary)
            .size(.medium)
          FCButton("일정 추가") { toast = .scheduleAdded() }
            .style(.secondary)
            .size(.medium)
          FCButton("팔로우") { toast = .followed("호락호락") }
            .style(.secondary)
            .size(.medium)
        }
        FCToast(.noLink())
      }
      DemoSection("Banner") {
        FCBanner("시간표가 바뀌었어요 · 3개 변경") {}
      }
      DemoSection("Dialog · Login Sheet · Report Sheet") {
        FCButton("확인 다이얼로그") {
          dialog = FCDialogItem(
            title: "이 안내를 숨길까요?",
            message: "마이 > 설정에서 다시 켤 수 있어요.",
            onConfirm: {}
          )
        }
        .style(.secondary)
        .isFullWidth(true)
        FCButton("로그인 시트") { sheet = .login }
          .style(.secondary)
          .isFullWidth(true)
        FCButton("신고 시트") { sheet = .report }
          .style(.secondary)
          .isFullWidth(true)
      }
    }
    .presentFCSheet(item: $sheet) { sheet in
      switch sheet {
      case .login:
        FCLoginSheet(
          title: "깃발을 팔로우 하려면 로그인이 필요해요",
          message: "내 취향의 깃발을 팔로우하고, 함께 페스티벌을 즐길 사람들과 크루를 만들어봐요.",
          onApple: {},
          onGoogle: {}
        )
      case .report:
        FCReportSheet(
          selection: $reportSelection,
          options: ["가짜 깃발이에요", "부적절한 사진이나 소개예요", "기타"],
          onSubmit: { _ in self.sheet = nil }
        )
      }
    }
    .fcDialog(item: $dialog)
    .fcToast(item: $toast)
  }
}

#Preview {
  NavigationStack {
    OverlayView()
  }
}
