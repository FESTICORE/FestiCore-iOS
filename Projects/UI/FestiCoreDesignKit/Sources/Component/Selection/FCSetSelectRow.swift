//
//  FCSetSelectRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 내 일정 고르기 한 줄. 시간이 겹치면 경고 문구를 표시한다.
public struct FCSetSelectRow: View {
  private var artist: String
  private var stage: String
  private var start: String
  private var end: String
  private var isSelected: Bool
  private var action: () -> Void
  private(set) var overlapText: String?

  public init(
    artist: String,
    stage: String,
    start: String,
    end: String,
    isSelected: Bool,
    action: @escaping () -> Void
  ) {
    self.artist = artist
    self.stage = stage
    self.start = start
    self.end = end
    self.isSelected = isSelected
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
          Text(start)
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          Text(end)
            .festiCoreFont(.baseCaption1Regular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
        .monospacedDigit()
        .frame(width: Metric.timeWidth, alignment: .leading)
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
          Text(artist)
            .festiCoreFont(.baseBodyBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          Text(stage)
            .festiCoreFont(.baseCaption2Medium)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          if let overlapText {
            HStack(spacing: FestiCoreSpacing.paddingP4) {
              Image(asset: .triangleExclamation16)
                .resizable()
                .frame(width: Metric.overlapIconSize, height: Metric.overlapIconSize)
              Text(overlapText)
                .festiCoreFont(.baseCaption1Medium)
            }
            .foregroundStyle(FestiCoreSemanticColor.accentForegroundOrange.color)
            .padding(.top, FestiCoreSpacing.paddingP4)
          }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        selectMark
      }
      .padding(.vertical, FestiCoreSpacing.paddingP12)
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .background(
        isSelected ? FestiCoreSemanticColor.accentBackgroundLime.color : FestiCoreSemanticColor.backgroundElevated.color
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var selectMark: some View {
    Image(asset: isSelected ? .check : .plus16)
      .resizable()
      .frame(width: Metric.iconSize, height: Metric.iconSize)
      .foregroundStyle(isSelected ? FestiCoreSemanticColor.staticInk.color : FestiCoreSemanticColor.labelAssistive.color)
      .frame(width: Metric.selectSize, height: Metric.selectSize)
      .background(isSelected ? FestiCoreSemanticColor.staticLime.color : .clear, in: Circle())
      .accessibilityHidden(true)
  }
}

// MARK: - 체이닝 설정

public extension FCSetSelectRow {
  /// 겹침 경고 문구를 바꾼 사본을 돌려준다.
  func overlapText(_ overlapText: String?) -> Self {
    var copy = self
    copy.overlapText = overlapText
    return copy
  }
}

private extension FCSetSelectRow {
  enum Metric {
    static let timeWidth: CGFloat = 48
    static let selectSize: CGFloat = 28
    static let iconSize: CGFloat = 16
    static let overlapIconSize: CGFloat = 12
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP12) {
    FCSetSelectRow(artist: "coldrain", stage: "WONDER STAGE", start: "16:40", end: "17:30", isSelected: false) {}
    FCSetSelectRow(artist: "coldrain", stage: "WONDER STAGE", start: "16:40", end: "17:30", isSelected: true) {}
      .overlapText("SPYAIR와 20분 겹쳐요")
  }
  .padding(FestiCoreSpacing.paddingP12)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
