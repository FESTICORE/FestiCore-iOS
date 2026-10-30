//
//  CardView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct CardView: View {
  @State private var isBooked = true
  @State private var isFollowing = false

  private let title = "펜타포트 락 페스티벌 2026"
  private let meta = "인천 송도달빛축제공원 · 8/7(금) – 8/9(일)"

  var body: some View {
    DemoPage("06 Cards 검증") {
      DemoSection("Festival Card (status × booked × pack)") {
        FCFestivalCard(
          title: title,
          meta: meta,
          status: .dDay("D-12")
        )
        .booked(isBooked) { isBooked.toggle() }
        .pack(isBooked ? .ready {} : .unavailable("예매한 페스티벌로 등록하면 팩을 받을 수 있어요"))
        .ticketLink {}
        FCFestivalCard(
          title: title,
          meta: meta,
          status: .closing("D-2")
        )
        .booked(true) {}
        .pack(.downloading(progress: 0.62, text: "팩 받는 중 · 62%"))
        .ticketLink {}
        FCFestivalCard(
          title: title,
          meta: meta,
          status: .dDay("D-12")
        )
        .booked(true) {}
        .pack(.received("팩 받음 · 최신 버전"))
        .ticketLink {}
        FCFestivalCard(
          title: title,
          meta: meta,
          status: .upcoming()
        )
        .booked(false) {}
        .pack(.unavailable("티켓 오픈 후 등록하고 팩을 받을 수 있어요"))
        .ticketLink {}
        FCFestivalCard(
          title: title,
          meta: meta,
          status: .ended()
        )
        .booked(false) {}
        .pack(.unavailable("종료된 페스티벌이라 팩을 받을 수 없어요"))
        .ticketLink {}
      }
      DemoSection("Flag Card (board · directory) · Flag Tile") {
        FCFlagCard(
          name: "호락호락",
          status: .active,
          zone: "리벳 앞 왼쪽",
          context: .board(activity: "슬램", time: "4분 전")
        )
        FCFlagCard(
          name: "호락호락",
          status: .active,
          zone: "리벳 앞 왼쪽",
          context: .directory(followers: "팔로워 1,284", tags: ["슬램", "떼창", "초보 환영"], isFollowing: isFollowing) {
            isFollowing.toggle()
          }
        )
        FCFlagTile(
          name: "호락호락",
          status: .active,
          zone: "리벳 앞 왼쪽",
          tags: "슬램 · 떼창",
          time: "5분 전"
        ) {}
          .frame(width: 165)
      }
      DemoSection("Flag Hero (following)") {
        FCFlagHero(
          name: "호락호락",
          followers: "팔로워 1,284",
          tags: ["슬램", "떼창", "초보 환영"],
          status: .active,
          intro: "“처음 와도 괜찮아요. 슬램은 앞쪽, 쉬고 싶으면 뒤쪽 깃발 아래로 오세요.”",
          isFollowing: isFollowing,
          onFollow: { isFollowing.toggle() }
        ) {
          FestiCoreSemanticColor.staticInk.color
        }
      }
      DemoSection("Flag Now Card (active · muted · ended)") {
        FCFlagNowCard(.active(zone: "리벳 앞 왼쪽", activity: "슬램", source: "기수가 4분 전에 알렸어요"))
        FCFlagNowCard(.muted(zone: "리벳 앞 왼쪽", activity: "슬램", source: "기수가 4분 전에 알렸어요"))
        FCFlagNowCard(.ended())
      }
      DemoSection("Plan Private · Next Set · Countdown") {
        FCPlanPrivate()
        FCNextSetCard(
          artist: "노이즈캔디",
          meta: "리벳 스테이지 · 15:40–16:30",
          remain: "12분 후",
          updated: "2분 전 업데이트",
          progress: 0.72
        )
        FCCountdownCard(
          label: "개장까지",
          time: "2시간 14분",
          sub: "12:00 개장 · 첫 공연 13:00 리벳 스테이지"
        )
      }
      DemoSection("Home · Last Ride · Done") {
        FCHomeCard(
          remain: "막차까지 52분",
          shuttle: "마지막 셔틀 23:40 · 정문 셔틀 정류장",
          train: "막차 23:52 · 서현역 (도보 12분)",
          actions: [
            FCCardAction("가는 길", style: .accent) {},
            FCCardAction("같이 귀가") {},
          ]
        )
        FCLastRideCard(
          shuttle: "23:40",
          train: "23:52"
        )
        FCDoneCard(
          title: "오늘 수고했어요",
          sub: "원더리벳 2026 DAY 1 · 12:00–23:00",
          stats: [
            .init(value: "4", label: "본 공연"),
            .init(value: "4명", label: "함께한 크루"),
            .init(value: "2", label: "팔로우한 깃발"),
          ]
        )
      }
      DemoSection("Empty · Bearer Header · Guide Section") {
        FCEmptyCard(
          title: "아직 크루가 없어요",
          message: "친구를 초대하면 서로 어느 존에 있는지 바로 볼 수 있어요."
        )
        .action(FCCardAction("크루 만들기", style: .primary) {})
        FCBearerHeader(
          name: "호락호락",
          status: .active,
          statusText: "리벳 스테이지 앞 왼쪽 · 슬램 · 4분 전",
          followers: "팔로워 1,284명이 보고 있어요"
        )
        FCGuideSection(
          title: "셔틀",
          message: "송도역 2번 출구 ↔ 행사장 입구 왼쪽 셔틀 존. 15분 간격으로 운행해요.",
          actions: [
            FCCardAction("셔틀 예약하기") {},
            FCCardAction("네이버 지도") {},
          ]
        )
      }
    }
  }
}

#Preview {
  NavigationStack {
    CardView()
  }
}
