//
//  FestiCoreDesignKitCatalogView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/23/26.
//

import FestiCoreDesignKit
import SwiftUI

struct FestiCoreDesignKitCatalogView: View {
  @State private var searchText = ""
  @State private var tabSelection = 0
  @State private var segmentSelection = 0
  @State private var tabBarSelection: FCTabBar.Tab = .live
  @State private var isFollowing = false
  @State private var isBigButtonSelected = false
  @State private var isChipSelected = true
  @State private var sortSelection = 0

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          colorSection
          FCDivider()
          typographySection
          FCDivider()
          buttonSection
          FCDivider()
          actionSection
          FCDivider()
          navigationSection
          FCDivider()
          timetableSection
        }
        .padding(FestiCoreSpacing.paddingP20)
      }
      .background(FestiCoreSemanticColor.backgroundNormal.color)
      .navigationTitle("FestiCoreDesignKit")
    }
  }

  private var colorSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      sectionTitle("Colors")
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        colorSwatch("Primary", color: .primaryNormal)
        colorSwatch("Secondary", color: .secondaryNormal)
        colorSwatch("Positive", color: .statusPositive)
        colorSwatch("Negative", color: .statusNegative)
      }
    }
  }

  private var typographySection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      sectionTitle("Typography")
      Text("FestiCore Title")
        .festiCoreFont(.baseTitle1Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
      Text("Pretendard 본문 텍스트")
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text("Caption · 작은 설명")
        .festiCoreFont(.baseCaption1Regular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  private var buttonSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      sectionTitle("Button")
      FCPrimaryButton("기본 버튼") {}
      FCPrimaryButton("비활성 버튼", isEnabled: false) {}
    }
  }

  private var actionSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      sectionTitle("Actions")
      ForEach([FCButton.Style.primary, .secondary, .ghost, .accent, .inverse], id: \.self) { style in
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          FCButton("버튼") {}
            .style(style)
          FCButton("버튼") {}
            .style(style)
            .size(.medium)
          FCButton("버튼") {}
            .style(style)
            .isEnabled(false)
        }
      }
      FCHeroFollowButton(isFollowing: isFollowing) { isFollowing.toggle() }
        .padding(FestiCoreSpacing.paddingP12)
        .background(FestiCoreSemanticColor.staticalphaBlack80.color)
      FCBigButton("존", sub: "리벳 앞 왼쪽", icon: .locationDot) { isBigButtonSelected.toggle() }
        .isSelected(isBigButtonSelected)
        .frame(width: 168, height: 180)
      FCLoginButton(.apple) {}
      FCLoginButton(.google) {}
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        FCChip("전체") { isChipSelected.toggle() }
          .isSelected(isChipSelected)
        Spacer()
        FCSortButton(sortItems[sortSelection]) {}
      }
      FCSortMenu(selection: $sortSelection, items: sortItems)
      FCBackPill("관객 화면으로") {}
      FCBearerPrompt {}
      VStack(spacing: FestiCoreSpacing.paddingP24) {
        FCBearerCTA(.start) {}
        FCBearerCTA(.restart) {}
      }
      .padding(FestiCoreSpacing.paddingP16)
      .background(FestiCoreSemanticColor.backgroundAlternative.color)
      .environment(\.colorScheme, .dark)
    }
  }

  private var sortItems: [String] {
    ["활동 중 순", "팔로워 많은 순", "최근 업데이트 순", "새로 생긴 순"]
  }

  private var navigationSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      sectionTitle("Navigation")
      FCTopBar(.logo)
        .showsBadge(true)
      FCTopBar(.logoBearer)
        .onBearer {}
      FCTopBar(.back, title: "라인업")
        .onBack {}
      FCTopBar(.large, title: "타임테이블")
      FCTopBar(.search(text: $searchText))
        .searchPlaceholder("아티스트 검색")
        .onCancel {}
      FCTopBar(.backOnImage, title: "아티스트")
        .onBack {}
        .background(FestiCoreSemanticColor.accentPointOrange.color)
      FCTab(selection: $tabSelection, items: ["1일차", "2일차", "3일차"])
      FCSegmented(selection: $segmentSelection, items: ["전체", "내 일정"])
      FCStepHeader(step: 2)
        .onLater {}
      FCTabBar(selection: $tabBarSelection)
    }
  }

  private var timetableSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      sectionTitle("Timetable")
      FCStageHeader(name: "메인 스테이지")
      FCStageHeader(name: "서브 스테이지")
        .dotColor(.accentPointOrange)
      HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
        FCSetBlock(artist: "아티스트", time: "18:00 - 19:00")
          .frame(height: FCSetBlock.height(minutes: 60))
        FCSetBlock(artist: "아티스트", time: "18:00 - 19:00")
          .state(.mine)
          .frame(height: FCSetBlock.height(minutes: 60))
      }
      HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
        FCSetBlock(artist: "아티스트", time: "18:30 - 19:30")
          .state(.changed(oldTime: "18:00", change: "30분 지연"))
          .frame(height: FCSetBlock.height(minutes: 60))
        FCSetBlock(artist: "아티스트", time: "18:00 - 18:20")
          .state(.overlap())
          .frame(height: FCSetBlock.height(minutes: 20))
      }
      FCNowLine(time: "18:30")
      FCOverlapHighlight()
        .frame(height: 40)
    }
  }

  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .festiCoreFont(.baseHeadlineBold)
      .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
  }

  private func colorSwatch(_ title: String, color: FestiCoreSemanticColor) -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      color.color
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r8))
      Text(title)
        .festiCoreFont(.baseCaption2Medium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .frame(maxWidth: .infinity)
  }
}
