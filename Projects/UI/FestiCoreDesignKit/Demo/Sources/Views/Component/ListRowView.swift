//
//  ListRowView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct ListRowView: View {
  @State private var isOn = true
  @State private var isEditing = false

  var body: some View {
    DemoPage("05 List Rows 검증") {
      DemoSection("List Row (chevron · toggle · value)") {
        FCListRow("항목") {}
        FCListRow(
          "항목",
          isOn: $isOn
        )
        FCListRow("항목") {}
          .value("값")
      }
      DemoSection("Section Header") {
        FCSectionHeader("섹션 제목")
          .action("전체보기") {}
      }
      DemoSection("Notification Row (unread · read · 편집)") {
        FCNotificationRow(
          title: "노이즈캔디 10분 후 시작",
          message: "리벳 스테이지 · 15:40",
          time: "2분 전",
          isRead: false
        )
        FCNotificationRow(
          title: "노이즈캔디 10분 후 시작",
          message: "리벳 스테이지 · 15:40",
          time: "2분 전",
          isRead: true
        )
        .editing(isEditing, isSelected: true)
        FCListRow(
          "편집 모드",
          isOn: $isEditing
        )
      }
      DemoSection("Search Result Row (festival · artist)") {
        FCSearchResultRow(
          .festival(image: nil, dDay: "D-29"),
          title: "원더리벳 2026",
          meta: "11/21(토) - 11/22(일) · 인천 파라다이스시티"
        ) {}
        FCSearchResultRow(
          .artist(initial: "삼"),
          title: "삼보마스터",
          meta: "원더리벳 2026 · 11/21(토) 리벳 스테이지"
        ) {}
      }
      DemoSection("Crew Row (default · stale)") {
        FCCrewRow(
          name: "민지",
          zone: "리벳 앞 왼쪽",
          status: "밥",
          time: "3분 전"
        )
        .isMe(true)
        FCCrewRow(
          name: "민지",
          zone: "리벳 앞 왼쪽",
          status: "밥",
          time: "1시간 전"
        )
        .isStale(true)
      }
      DemoSection("Stage Row (mine · default)") {
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
        .background(FestiCoreSemanticColor.backgroundElevated.color)
      }
      DemoSection("Active Flag Row · Lineup Row") {
        FCActiveFlagRow(
          name: "앵콜원정대",
          meta: "원더 앞 · 떼창",
          time: "2분 전",
          status: .active
        ) {}
          .background(FestiCoreSemanticColor.backgroundElevated.color)
        FCLineupRow(
          number: "01",
          artist: "노이즈캔디"
        )
      }
      DemoSection("Plan Row (upcoming · now · past)") {
        VStack(spacing: 0) {
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
      DemoSection("Pack Row (latest · update)") {
        VStack(spacing: 0) {
          FCPackRow(
            name: "원더리벳 2026",
            meta: "최신 버전 · 10/16 14:00 확인"
          ) {}
          FCPackRow(
            name: "원더리벳 2026",
            meta: "최신 버전 · 10/16 14:00 확인"
          ) {}
            .hasUpdate(true)
        }
        .background(FestiCoreSemanticColor.backgroundElevated.color)
      }
    }
  }
}

#Preview {
  NavigationStack {
    ListRowView()
  }
}
