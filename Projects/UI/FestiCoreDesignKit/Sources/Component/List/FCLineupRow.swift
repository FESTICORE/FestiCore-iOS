//
//  FCLineupRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 시간표 공개 전 라인업 한 줄.
public struct FCLineupRow: View {
  private var number: String
  private var artist: String

  public init(
    number: String,
    artist: String
  ) {
    self.number = number
    self.artist = artist
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      Text(number)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .monospacedDigit()
        .frame(width: Metric.numberWidth, alignment: .leading)
      Text(artist)
        .festiCoreFont(.baseCalloutMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .lineLimit(1)
    .padding(FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .accessibilityElement(children: .combine)
  }
}

private extension FCLineupRow {
  enum Metric {
    static let numberWidth: CGFloat = 20
  }
}

#Preview {
  VStack(spacing: 0) {
    FCLineupRow(
      number: "01",
      artist: "노이즈캔디"
    )
    FCLineupRow(
      number: "02",
      artist: "스모킹구스"
    )
  }
  .padding(FestiCoreSpacing.paddingP24)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
