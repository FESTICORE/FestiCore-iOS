//
//  DemoPage.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 검증 화면 공통 틀. 세로 스크롤 안에 섹션을 쌓는다.
struct DemoPage<Content: View>: View {
  private let title: String
  private let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM24) {
        content
      }
      .padding(FestiCoreSpacing.paddingP20)
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

/// 검증 화면의 한 묶음. 제목 아래에 변형을 나열한다.
struct DemoSection<Content: View>: View {
  private let title: String
  private let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Text(title)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      content
    }
  }
}
