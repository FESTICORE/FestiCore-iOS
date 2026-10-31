//
//  OverlayView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

struct OverlayView: View {
  private enum Sheet: String, Identifiable {
    case login
    case report
    case set
    case zone
    case activity

    var id: String {
      rawValue
    }
  }

  @State private var sheet: Sheet?
  @State private var dialog: FCDialogItem?
  @State private var dimDismissDialog: FCDialogItem?
  @State private var alertDemo = Store(initialState: AlertDemoFeature.State()) { AlertDemoFeature() }
  @State private var toast: FCToast.Item?
  @State private var reportSelection: Int?
  @State private var checkOverlay: FCCheckOverlay.Item?
  @State private var isScheduled = false
  @State private var zoneID: String?
  @State private var activityID: String?

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
        FCButton("확인 다이얼로그 (딤 탭으로 닫기)") {
          dimDismissDialog = FCDialogItem(
            title: "로그아웃",
            message: "이 기기에서 로그아웃하시겠습니까?",
            confirmTitle: "로그아웃",
            onConfirm: {}
          )
        }
        .style(.secondary)
        .isFullWidth(true)
        FCButton("확인 다이얼로그 (Store · fcAlert)") { alertDemo.send(.showTapped) }
          .style(.secondary)
          .isFullWidth(true)
        FCButton("로그인 시트") { sheet = .login }
          .style(.secondary)
          .isFullWidth(true)
        FCButton("신고 시트") { sheet = .report }
          .style(.secondary)
          .isFullWidth(true)
      }
      DemoSection("Set Sheet · Bearer Choice Sheet") {
        FCButton("셋 상세 시트") { sheet = .set }
          .style(.secondary)
          .isFullWidth(true)
        FCButton("존 선택 시트") { sheet = .zone }
          .style(.secondary)
          .isFullWidth(true)
        FCButton("활동 선택 시트") { sheet = .activity }
          .style(.secondary)
          .isFullWidth(true)
      }
      DemoSection("Check Overlay (누르면 1초 표시)") {
        FCButton("존 바꾸기") {
          checkOverlay = FCCheckOverlay.Item(
            title: "리벳 스테이지 중앙으로 바꿨어요",
            message: "팔로워에게 알렸어요"
          )
        }
        .style(.secondary)
        .isFullWidth(true)
      }
      DemoSection("Search Empty") {
        FCSearchEmpty(query: "락페")
      }
      DemoSection("Done Hero") {
        FCDoneHero(
          title: "깃발이 준비됐어요",
          message: "공연 당일 기수 보드에서 깃발을 올리면\n팔로워에게 알림이 가요."
        )
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
      case .set:
        FCSetSheet(
          artist: "라임플래그스",
          stage: "리벳 스테이지",
          time: "17:00–17:50 · 50분",
          relativeTime: "1시간 32분 후",
          isScheduled: $isScheduled
        )
        .memo("앵콜 없이 정시에 끝나요. 리벳 앞 왼쪽이 덜 붐벼요.")
        .source("출처: 주최측 공지 · 확인 10/16 14:00")
      case .zone:
        FCBearerChoiceSheet(
          .zone,
          options: Self.zones,
          selectedID: zoneID,
          onSelect: { zoneID = $0.id }
        )
      case .activity:
        FCBearerChoiceSheet(
          .activity,
          options: Self.activities,
          selectedID: activityID,
          onSelect: { activityID = $0.id }
        )
      }
    }
    .fcDialog(item: $dialog)
    .modifier(AlertDemoPresenter(store: alertDemo))
    .overlay {
      if let dimDismissDialog {
        FCDialogOverlay(item: dimDismissDialog, dismissesOnDimTap: true) { self.dimDismissDialog = nil }
          .id(dimDismissDialog.id)
      }
    }
    .animation(.spring(response: 0.42, dampingFraction: 0.88), value: dimDismissDialog)
    .fcToast(item: $toast)
    .fcCheckOverlay(item: $checkOverlay)
  }
}

private extension OverlayView {
  static let zones = ["리벳 스테이지 앞 왼쪽", "리벳 스테이지 중앙", "리벳 스테이지 뒤", "원더 스테이지 앞", "TENT 앞", "슬램 존"]
    .map {
      FCBearerChoiceSheet.Option(
        id: $0,
        title: $0,
        icon: .locationDot16
      )
    }

  static let activities = [
    FCBearerChoiceSheet.Option(
      id: "slam",
      title: "슬램",
      icon: .users24
    ),
    FCBearerChoiceSheet.Option(
      id: "singalong",
      title: "떼창",
      icon: .music24
    ),
    FCBearerChoiceSheet.Option(
      id: "train",
      title: "기차놀이",
      icon: .route24
    ),
    FCBearerChoiceSheet.Option(
      id: "calm",
      title: "차분",
      icon: .user24
    )
  ]
}

#Preview {
  NavigationStack {
    OverlayView()
  }
}
