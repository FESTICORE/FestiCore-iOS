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
  private var highlightedQuery = ""
  private var isUrgent = false
  private(set) var thumbnail: AnyView?

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
          highlightedTitle
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .accessibilityLabel(title)
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

  @ViewBuilder
  private var leading: some View {
    switch kind {
    case let .festival(image, _):
      if let thumbnail {
        thumbnail
          .frame(width: Metric.leadingSize, height: Metric.leadingSize)
          .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
          .accessibilityHidden(true)
      } else {
        FCThumbnail(image)
          .placeholderIcon(.music20)
          .size(Metric.leadingSize)
      }
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
          .foregroundStyle(
            isUrgent ? FestiCoreSemanticColor.staticWhite.color : FestiCoreSemanticColor.inverseLabel.color
          )
          .padding(.vertical, FestiCoreSpacing.paddingP4)
          .padding(.horizontal, FestiCoreSpacing.marginM6)
          .background(
            isUrgent ? FestiCoreSemanticColor.accentPointRed.color : FestiCoreSemanticColor.inverseBackground.color,
            in: RoundedRectangle(cornerRadius: FestiCoreRadius.r4)
          )
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

// MARK: - 체이닝 설정

public extension FCSearchResultRow {
  /// festival 썸네일 자리에 원격 이미지 같은 뷰를 넣은 사본을 돌려준다. 48pt 정사각형으로 자른다.
  func thumbnail(_ view: some View) -> Self {
    var copy = self
    copy.thumbnail = AnyView(view)
    return copy
  }

  /// 제목에서 검색어와 일치하는 부분을 강조한다.
  func highlightedQuery(_ query: String) -> Self {
    var copy = self
    copy.highlightedQuery = query
    return copy
  }

  /// 임박한 공연 날짜 배지를 경고색으로 표시한다.
  func urgent(_ isUrgent: Bool) -> Self {
    var copy = self
    copy.isUrgent = isUrgent
    return copy
  }
}

private extension FCSearchResultRow {
  var highlightedTitle: Text {
    guard !highlightedQuery.isEmpty else { return Text(title) }
    var remaining = title[...]
    var result = Text("")
    while let range = remaining.range(
      of: highlightedQuery,
      options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
      locale: .current
    ), !range.isEmpty {
      result = result
        + Text(String(remaining[..<range.lowerBound]))
        + Text(String(remaining[range])).foregroundColor(FestiCoreSemanticColor.secondaryNormal.color)
      remaining = remaining[range.upperBound...]
    }
    return result + Text(String(remaining))
  }

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
