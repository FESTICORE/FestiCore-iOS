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
  @State private var tabBarSelection: FestiCoreTabBar.Tab = .live

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          colorSection
          FestiCoreDivider()
          typographySection
          FestiCoreDivider()
          buttonSection
          FestiCoreDivider()
          navigationSection
          FestiCoreDivider()
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
      FestiCorePrimaryButton("기본 버튼") {}
      FestiCorePrimaryButton("비활성 버튼", isEnabled: false) {}
    }
  }

  private var navigationSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      sectionTitle("Navigation")
      FestiCoreTopBar(.logo)
        .showsBadge(true)
      FestiCoreTopBar(.logoBearer)
        .onBearer {}
      FestiCoreTopBar(.back, title: "라인업")
        .onBack {}
      FestiCoreTopBar(.large, title: "타임테이블")
      FestiCoreTopBar(.search(text: $searchText))
        .searchPlaceholder("아티스트 검색")
        .onCancel {}
      FestiCoreTopBar(.backOnImage, title: "아티스트")
        .onBack {}
        .background(FestiCoreSemanticColor.accentPointOrange.color)
      FestiCoreTab(selection: $tabSelection, items: ["1일차", "2일차", "3일차"])
      FestiCoreSegmented(selection: $segmentSelection, items: ["전체", "내 일정"])
      FestiCoreStepHeader(step: 2)
        .onLater {}
      FestiCoreTabBar(selection: $tabBarSelection)
    }
  }

  private var timetableSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      sectionTitle("Timetable")
      FestiCoreStageHeader(name: "메인 스테이지")
      FestiCoreStageHeader(name: "서브 스테이지")
        .dotColor(.accentPointOrange)
      HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
        FestiCoreSetBlock(artist: "아티스트", time: "18:00 - 19:00")
          .frame(height: FestiCoreSetBlock.height(minutes: 60))
        FestiCoreSetBlock(artist: "아티스트", time: "18:00 - 19:00")
          .state(.mine)
          .frame(height: FestiCoreSetBlock.height(minutes: 60))
      }
      HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
        FestiCoreSetBlock(artist: "아티스트", time: "18:30 - 19:30")
          .state(.changed(oldTime: "18:00", change: "30분 지연"))
          .frame(height: FestiCoreSetBlock.height(minutes: 60))
        FestiCoreSetBlock(artist: "아티스트", time: "18:00 - 18:20")
          .state(.overlap())
          .frame(height: FestiCoreSetBlock.height(minutes: 20))
      }
      FestiCoreNowLine(time: "18:30")
      FestiCoreOverlapHighlight()
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
