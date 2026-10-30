//
//  FCSearchResultRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 검색 결과 한 줄. festival은 썸네일과 D-day, artist는 이니셜과 화살표를 표시한다.
public struct FCSearchResultRow: View {
  public enum Kind {
    case festival(image: Image?, dDay: String?)
    case artist(initial: String)
  }

  private var kind: Kind
  private var title: String
  private var meta: String
  private var action: () -> Void

  public init(
    _ kind: Kind,
    title: String,
    meta: String,
    action: @escaping () -> Void
  ) {
    self.kind = kind
    self.title = title
    self.meta = meta
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        leading
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
          Text(title)
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          Text(meta)
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        trailing
      }
      .padding(.vertical, FestiCoreSpacing.paddingP12)
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .background(FestiCoreSemanticColor.backgroundNormal.color)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

}

private extension FCSearchResultRow {
  @ViewBuilder
  var leading: some View {
    switch kind {
    case let .festival(image, _):
      FCThumbnail(image)
        .placeholderIcon(.music20)
        .size(Metric.leadingSize)
    case let .artist(initial):
      FCAvatar(initial)
        .size(.large)
    }
  }

  @ViewBuilder
  private var trailing: some View {
    switch kind {
    case let .festival(_, dDay):
      if let dDay {
        Text(dDay)
          .festiCoreFont(.baseCaption2Bold)
          .foregroundStyle(FestiCoreSemanticColor.inverseLabel.color)
          .padding(.vertical, FestiCoreSpacing.paddingP4)
          .padding(.horizontal, FestiCoreSpacing.marginM6)
          .background(FestiCoreSemanticColor.inverseBackground.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r4))
      }
    case .artist:
      Image(asset: .chevronRight16)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .accessibilityHidden(true)
    }
  }
}

private extension FCSearchResultRow {
  enum Metric {
    static let leadingSize: CGFloat = 48
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCSearchResultRow(
      .festival(image: nil, dDay: "D-29"),
      title: "원더리벳 2026",
      meta: "11/21(토) - 11/22(일) · 인천 파라다이스시티"
    ) {}
    FCSearchResultRow(
      .artist(initial: "삼"),
      title: "삼보마스터",
      meta: "원더리벳 2026 · 11/21(토) 리벳 스테이지"
    ) {}
  }
}
