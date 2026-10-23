//
//  FestiCoreDesignKitCatalogView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/23/26.
//

import FestiCoreDesignKit
import SwiftUI

struct FestiCoreDesignKitCatalogView: View {
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          colorSection
          FestiCoreDivider()
          typographySection
          FestiCoreDivider()
          buttonSection
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
        .festiCoreTextStyle(FestiCoreTypography.baseTitle1Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
      Text("Pretendard 본문 텍스트")
        .festiCoreTextStyle(FestiCoreTypography.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text("Caption · 작은 설명")
        .festiCoreTextStyle(FestiCoreTypography.baseCaption1Regular)
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

  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .festiCoreTextStyle(FestiCoreTypography.baseHeadlineBold)
      .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
  }

  private func colorSwatch(_ title: String, color: FestiCoreSemanticColor) -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      color.color
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r8))
      Text(title)
        .festiCoreTextStyle(FestiCoreTypography.baseCaption2Medium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .frame(maxWidth: .infinity)
  }
}
