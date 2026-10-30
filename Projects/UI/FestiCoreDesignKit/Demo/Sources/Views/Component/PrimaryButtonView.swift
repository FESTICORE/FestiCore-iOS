//
//  PrimaryButtonView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct PrimaryButtonView: View {
  var body: some View {
    DemoPage("Primary Button 검증") {
      DemoSection("State (default · disabled)") {
        FCPrimaryButton("기본 버튼") {}
        FCPrimaryButton(
          "비활성 버튼",
          isEnabled: false
        ) {}
      }
    }
  }
}

#Preview {
  NavigationStack {
    PrimaryButtonView()
  }
}
