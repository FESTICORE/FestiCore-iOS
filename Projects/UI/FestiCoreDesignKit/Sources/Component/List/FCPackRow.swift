//
//  FCPackRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// "내가 받은 팩" 한 줄. 새 버전이 있으면 업데이트 태그를 붙이고 누르면 팩 상세로 이동한다.
public struct FCPackRow: View {
  private var name: String
  private var meta: String
  private var action: () -> Void
  private(set) var image: Image?
  private(set) var hasUpdate = false
  private(set) var updateLabel = "업데이트"

  public init(
    name: String,
    meta: String,
    action: @escaping () -> Void
  ) {
    self.name = name
    self.meta = meta
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        FCThumbnail(image)
          .size(Metric.thumbnailSize)
        VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM2) {
          Text(name)
            .festiCoreFont(.baseCalloutMedium)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          Text(meta)
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        if hasUpdate {
          FCTag(updateLabel)
            .tone(.warning)
        }
        Image(asset: .chevronRight16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .accessibilityHidden(true)
      }
      .padding(.vertical, FestiCoreSpacing.paddingP12)
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - 체이닝 설정

public extension FCPackRow {
  /// 썸네일 이미지를 바꾼 사본을 돌려준다.
  func image(_ image: Image?) -> Self {
    var copy = self
    copy.image = image
    return copy
  }

  /// 새 버전 여부와 태그 글자를 바꾼 사본을 돌려준다.
  func hasUpdate(
    _ hasUpdate: Bool,
    label: String = "업데이트"
  ) -> Self {
    var copy = self
    copy.hasUpdate = hasUpdate
    copy.updateLabel = label
    return copy
  }
}

private extension FCPackRow {
  enum Metric {
    static let thumbnailSize: CGFloat = 44
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCPackRow(
      name: "원더리벳 2026",
      meta: "최신 버전 · 10/16 14:00 확인"
    ) {}
    FCPackRow(
      name: "원더리벳 2026",
      meta: "최신 버전 · 10/16 14:00 확인"
    ) {}
      .hasUpdate(true)
  }
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
