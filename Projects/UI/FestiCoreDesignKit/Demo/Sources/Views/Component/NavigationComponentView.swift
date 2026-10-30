//
//  NavigationComponentView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct NavigationComponentView: View {
  @State private var searchText = ""
  @State private var tabSelection = 0
  @State private var segmentSelection = 0
  @State private var tabBarSelection: FCTabBar.Tab = .live

  var body: some View {
    DemoPage("01 Navigation 검증") {
      DemoSection("Top Bar (logo · logoBearer · back · large · search · backOnImage)") {
        FCTopBar(.logo)
          .showsBadge(true)
        FCTopBar(.logoBearer)
          .onBearer {}
        FCTopBar(
          .back,
          title: "라인업"
        )
          .onBack {}
        FCTopBar(
          .large,
          title: "타임테이블"
        )
        FCTopBar(.search(text: $searchText))
          .searchPlaceholder("아티스트 검색")
          .onCancel {}
        FCTopBar(
          .backOnImage,
          title: "아티스트"
        )
          .onBack {}
          .background(FestiCoreSemanticColor.accentPointOrange.color)
      }
      DemoSection("Tab · Segmented") {
        FCTab(
          selection: $tabSelection,
          items: ["1일차", "2일차", "3일차"]
        )
        FCSegmented(
          selection: $segmentSelection,
          items: ["전체", "내 일정"]
        )
      }
      DemoSection("Step Header") {
        FCStepHeader(step: 2)
          .onLater {}
      }
      DemoSection("Pagination (다크 배경 전용)") {
        VStack(spacing: FestiCoreSpacing.paddingP16) {
          ForEach(1...4, id: \.self) { page in
            FCPagination(current: page)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(FestiCoreSpacing.paddingP24)
        .background(FestiCoreSemanticColor.staticInk.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
      }
      DemoSection("Tab Bar") {
        FCTabBar(selection: $tabBarSelection)
      }
    }
  }
}

#Preview {
  NavigationStack {
    NavigationComponentView()
  }
}
