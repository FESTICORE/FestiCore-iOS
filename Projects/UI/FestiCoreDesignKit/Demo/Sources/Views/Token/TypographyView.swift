//
//  TypographyView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct TypographyView: View {
  var body: some View {
    DemoPage("Typography 검증") {
      DemoSection("Pretendard") {
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
  }
}

#Preview {
  NavigationStack {
    TypographyView()
  }
}
