//
//  FCLineupRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 시간표 공개 전 라인업 한 줄(Figma Lineup Row: 번호·40 썸네일·아티스트).
public struct FCLineupRow: View {
  private var number: String
  private var artist: String
  private var showsSeparator: Bool
  private(set) var thumbnail: AnyView?

  public init(
    number: String,
    artist: String,
    showsSeparator: Bool = true
  ) {
    self.number = number
    self.artist = artist
    self.showsSeparator = showsSeparator
  }

  public var body: some View {
    VStack(spacing: .zero) {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        Text(number)
          .festiCoreFont(.baseFootnoteBold)
          .festiCoreLineBox(.baseFootnoteBold)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .monospacedDigit()
          .frame(
            width: Metric.numberWidth,
            alignment: .leading
          )
        // Figma 11-12: 썸네일은 번호와 아티스트 사이(x48)에 둔다.
        thumbnailView
        Text(artist)
          .festiCoreFont(.baseCalloutMedium)
          .festiCoreLineBox(.baseCalloutMedium)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )
      }
      .lineLimit(1)
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )
      .padding(
        .vertical,
        FestiCoreSpacing.paddingP12
      )
      // Figma 행 65 = 64 + 아래 구분선 1, 마지막 행은 64
      if showsSeparator {
        FestiCoreSemanticColor.lineNormal.color
          .frame(height: 1)
      }
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .accessibilityElement(children: .combine)
  }
}

private extension FCLineupRow {
  /// Figma Thumbnail 40×40 r8, 사진이 없으면 Fill/Strong 바탕만 보인다.
  var thumbnailView: some View {
    return FestiCoreSemanticColor.fillStrong.color
      .overlay { thumbnail }
      .frame(
        width: Metric.thumbnailSize,
        height: Metric.thumbnailSize
      )
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r8))
      .accessibilityHidden(true)
  }

  enum Metric {
    static let numberWidth: CGFloat = 20
    static let thumbnailSize: CGFloat = 40
  }
}

// MARK: - 체이닝 설정

public extension FCLineupRow {
  /// 썸네일 자리에 채울 사진 뷰를 바꾼 사본을 돌려준다.
  func thumbnail<Content: View>(_ content: Content) -> Self {
    var copy = self
    copy.thumbnail = AnyView(content)
    return copy
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
