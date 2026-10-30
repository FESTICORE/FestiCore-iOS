//
//  FCActiveFlagRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 활성 깃발 전체 리스트 한 줄. 최근 업데이트 순으로 쌓는다.
public struct FCActiveFlagRow: View {
  private var name: String
  private var meta: String
  private var time: String
  private var status: FCStatusChip.Status
  private var action: () -> Void
  private(set) var image: Image?

  public init(
    name: String,
    meta: String,
    time: String,
    status: FCStatusChip.Status,
    action: @escaping () -> Void
  ) {
    self.name = name
    self.meta = meta
    self.time = time
    self.status = status
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        FCThumbnail(image)
          .size(Metric.thumbnailSize, cornerRadius: FestiCoreRadius.r12)
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
          Text(name)
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          Text(meta)
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .trailing, spacing: FestiCoreSpacing.paddingP4) {
          FCStatusChip(status)
          Text(time)
            .festiCoreFont(.baseCaption1Regular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
      }
      .padding(.vertical, FestiCoreSpacing.paddingP12)
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - 체이닝 설정

public extension FCActiveFlagRow {
  /// 깃발 사진을 바꾼 사본을 돌려준다. `nil`이면 빈 썸네일을 보인다.
  func image(_ image: Image?) -> Self {
    var copy = self
    copy.image = image
    return copy
  }
}

private extension FCActiveFlagRow {
  enum Metric {
    static let thumbnailSize: CGFloat = 40
  }
}

#Preview {
  FCActiveFlagRow(
    name: "앵콜원정대",
    meta: "원더 앞 · 떼창",
    time: "2분 전",
    status: .active
  ) {}
    .background(FestiCoreSemanticColor.backgroundElevated.color)
}
