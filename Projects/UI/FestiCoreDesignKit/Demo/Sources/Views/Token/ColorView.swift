//
//  ColorView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct ColorView: View {
  var body: some View {
    DemoPage("Color 검증") {
      DemoSection("Brand · Status") {
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          swatch("Primary", color: .primaryNormal)
          swatch("Secondary", color: .secondaryNormal)
          swatch("Positive", color: .statusPositive)
          swatch("Negative", color: .statusNegative)
        }
      }
    }
  }
}

private extension ColorView {
  func swatch(
    _ title: String,
    color: FestiCoreSemanticColor
  ) -> some View {
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

#Preview {
  NavigationStack {
    ColorView()
  }
}
