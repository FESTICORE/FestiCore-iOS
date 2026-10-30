//
//  ActionView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct ActionView: View {
  @State private var isFollowing = false
  @State private var isBigButtonSelected = false
  @State private var isChipSelected = true
  @State private var sortSelection = 0

  private let sortItems = ["활동 중 순", "팔로워 많은 순", "최근 업데이트 순", "새로 생긴 순"]

  var body: some View {
    DemoPage("02 Actions 검증") {
      DemoSection("Button (style × size × state)") {
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
      }
      DemoSection("Hero Follow Button") {
        FCHeroFollowButton(isFollowing: isFollowing) { isFollowing.toggle() }
          .padding(FestiCoreSpacing.paddingP12)
          .background(FestiCoreSemanticColor.staticalphaBlack80.color)
      }
      DemoSection("Big Button") {
        FCBigButton(
          "존",
          sub: "리벳 앞 왼쪽",
          icon: .locationDot
        ) { isBigButtonSelected.toggle() }
          .isSelected(isBigButtonSelected)
          .frame(width: 168, height: 180)
      }
      DemoSection("Login Button") {
        FCLoginButton(.apple) {}
        FCLoginButton(.google) {}
      }
      DemoSection("Chip · Sort Button · Sort Menu") {
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          FCChip("전체") { isChipSelected.toggle() }
            .isSelected(isChipSelected)
          Spacer()
          FCSortButton(sortItems[sortSelection]) {}
        }
        FCSortMenu(
          selection: $sortSelection,
          items: sortItems
        )
      }
      DemoSection("Back Pill · Bearer Prompt") {
        FCBackPill("관객 화면으로") {}
        FCBearerPrompt {}
      }
      DemoSection("Bearer CTA (start · restart)") {
        VStack(spacing: FestiCoreSpacing.paddingP24) {
          FCBearerCTA(.start) {}
          FCBearerCTA(.restart) {}
        }
        .padding(FestiCoreSpacing.paddingP16)
        .background(FestiCoreSemanticColor.backgroundAlternative.color)
        .environment(\.colorScheme, .dark)
      }
    }
  }
}

#Preview {
  NavigationStack {
    ActionView()
  }
}
