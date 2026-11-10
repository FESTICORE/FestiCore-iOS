//
//  FCSectionHeader.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 섹션 제목과 오른쪽 보조 글·전체보기.
public struct FCSectionHeader: View {
  private var title: String
  private(set) var actionTitle: String?
  private(set) var action: (() -> Void)?
  private(set) var isCompact = false

  public init(_ title: String) {
    self.title = title
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP16) {
      Text(title)
        // Figma Section Header 제목: Base/Headline/Bold, 작은 머리글은 Base/Footnote/Bold
        .festiCoreFont(isCompact ? .baseFootnoteBold : .baseHeadlineBold)
        .festiCoreLineBox(isCompact ? .baseFootnoteBold : .baseHeadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
      if let actionTitle {
        if let action {
          Button(action: action) {
            actionText(actionTitle)
          }
          .buttonStyle(.plain)
        } else {
          actionText(actionTitle)
        }
      }
    }
    .frame(minHeight: isCompact ? nil : Metric.height)
  }

}

private extension FCSectionHeader {
  func actionText(_ text: String) -> some View {
    Text(text)
      .festiCoreFont(isCompact ? .baseFootnoteRegular : .baseFootnoteMedium)
      .festiCoreLineBox(isCompact ? .baseFootnoteRegular : .baseFootnoteMedium)
      .foregroundStyle(isCompact ? FestiCoreSemanticColor.labelAssistive.color : FestiCoreSemanticColor.labelNeutral.color)
      .lineLimit(1)
  }
}

// MARK: - 체이닝 설정

public extension FCSectionHeader {
  /// 오른쪽 글과 동작을 바꾼 사본을 돌려준다. 동작이 없으면 보조 글로만 표시한다.
  func action(
    _ title: String?,
    perform action: (() -> Void)? = nil
  ) -> Self {
    var copy = self
    copy.actionTitle = title
    copy.action = action
    return copy
  }

  /// 검색 목록처럼 작은 머리글(Figma S00 검색: Footnote/Bold 제목·Footnote/Regular 보조 글, 높이 18)로 바꾼 사본을 돌려준다.
  func compact(_ isCompact: Bool) -> Self {
    var copy = self
    copy.isCompact = isCompact
    return copy
  }
}

private extension FCSectionHeader {
  enum Metric {
    static let height: CGFloat = 28
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCSectionHeader("섹션 제목")
      .action("전체보기") {}
    FCSectionHeader("섹션 제목")
  }
  .padding(FestiCoreSpacing.paddingP24)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
