//
//  FestiCoreDesignKitFigmaSizeTests.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 11/10/26.
//

import SwiftUI
import Testing
import UIKit
@testable import FestiCoreDesignKit

/// Figma 원본(2026-11-10 내보냄) Design System - Component 페이지의 심볼 높이와 실제 렌더 높이를 맞춘다.
@MainActor
@Suite("DesignKit Figma 심볼 크기")
struct FestiCoreDesignKitFigmaSizeTests {
  @Test(
    "컴포넌트 렌더 높이가 Figma 심볼 높이와 같다",
    arguments: FigmaHeightCase.all
  )
  func componentHeightMatchesFigmaSymbol(_ testCase: FigmaHeightCase) {
    let size = renderedSize(
      testCase.view,
      width: testCase.width
    )

    #expect(
      abs(size.height - testCase.figmaHeight) <= 0.5,
      "\(testCase.name): 렌더 높이 \(size.height), Figma \(testCase.figmaHeight)"
    )
  }

  @Test("배지는 Figma 심볼처럼 16×16이다")
  func badgeMatchesFigmaSymbolSize() {
    let size = renderedSize(
      AnyView(FCBadge(count: 3)),
      width: nil
    )

    #expect(size == CGSize(
      width: 16,
      height: 16
    ))
  }

  @Test("존 칩은 좌우 테두리를 포함해 100×26이다")
  func zoneChipWidthIncludesBorderOnBothSides() {
    let size = renderedSize(
      AnyView(FCZoneChip("리벳 앞 왼쪽") {}),
      width: nil
    )

    // Figma Zone Chip 100×26 = 테두리 1 + 6 + 아이콘 16 + 8 + 글자 60 + 8 + 테두리 1
    #expect(abs(size.width - 100) <= 1.5)
    #expect(abs(size.height - 26) <= 0.5)
  }
}

struct FigmaHeightCase: Sendable, CustomTestStringConvertible {
  let name: String
  let figmaHeight: CGFloat
  let width: CGFloat?
  let makeView: @MainActor @Sendable () -> AnyView

  var testDescription: String {
    return name
  }

  @MainActor var view: AnyView {
    return makeView()
  }

  static let all: [FigmaHeightCase] = [
    FigmaHeightCase(
      name: "Tag",
      figmaHeight: 18,
      width: nil,
      makeView: { AnyView(FCTag("슬램")) }
    ),
    FigmaHeightCase(
      name: "Status Chip",
      figmaHeight: 24,
      width: nil,
      makeView: { AnyView(FCStatusChip(.active)) }
    ),
    FigmaHeightCase(
      name: "Live Badge",
      figmaHeight: 24,
      width: nil,
      makeView: { AnyView(FCLiveBadge(.now)) }
    ),
    FigmaHeightCase(
      name: "Offline Badge",
      figmaHeight: 36,
      width: 375,
      makeView: { AnyView(FCOfflineBadge("오프라인 · 3분 전 정보")) }
    ),
    FigmaHeightCase(
      name: "Source Line",
      figmaHeight: 40,
      width: 375,
      makeView: { AnyView(FCSourceLine("출처: 주최측 공지 · 확인 10/16 14:00")) }
    ),
    FigmaHeightCase(
      name: "Bearer Footer",
      figmaHeight: 42,
      width: 393,
      makeView: { AnyView(FCBearerFooter()) }
    ),
    FigmaHeightCase(
      name: "Checklist Progress",
      figmaHeight: 72,
      width: 361,
      makeView: {
        AnyView(FCChecklistProgress(
          checked: 3,
          total: 7
        ))
      }
    ),
    FigmaHeightCase(
      name: "Tab Item",
      figmaHeight: 46,
      width: nil,
      makeView: {
        AnyView(FCTabItem(
          "전체",
          isSelected: true
        ))
      }
    ),
    FigmaHeightCase(
      name: "Menu Item",
      figmaHeight: 48,
      width: 200,
      makeView: { AnyView(FCMenuItem("활동 중 순")) }
    ),
    FigmaHeightCase(
      name: "Sort Button",
      figmaHeight: 26,
      width: nil,
      makeView: {
        AnyView(FCSortButton(
          "활동 중 순",
          action: {}
        ))
      }
    ),
    FigmaHeightCase(
      name: "Recent Keyword",
      figmaHeight: 30,
      width: nil,
      makeView: {
        AnyView(FCRecentKeyword(
          "펜타포트",
          onSelect: {},
          onDelete: {}
        ))
      }
    ),
    FigmaHeightCase(
      name: "Field Label",
      figmaHeight: 18,
      width: 361,
      makeView: { AnyView(FCFieldLabel("성향 태그")) }
    ),
    FigmaHeightCase(
      name: "Checklist Row",
      figmaHeight: 49,
      width: 343,
      makeView: {
        AnyView(FCChecklistRow(
          "보조배터리",
          isChecked: false,
          action: {}
        ))
      }
    ),
    FigmaHeightCase(
      name: "Consent All",
      figmaHeight: 57,
      width: 343,
      makeView: {
        AnyView(FCConsentAll(
          isChecked: true,
          action: {}
        ))
      }
    ),
    FigmaHeightCase(
      name: "Banner",
      figmaHeight: 42,
      width: 343,
      makeView: {
        AnyView(FCBanner(
          "시간표가 바뀌었어요",
          action: {}
        ))
      }
    ),
  ]
}

@MainActor
private func renderedSize(
  _ view: AnyView,
  width: CGFloat?
) -> CGSize {
  let controller = UIHostingController(rootView: view)
  controller.sizingOptions = .intrinsicContentSize
  let target = CGSize(
    width: width ?? UIView.layoutFittingExpandedSize.width,
    height: UIView.layoutFittingExpandedSize.height
  )
  let size = controller.sizeThatFits(in: target)
  return CGSize(
    width: width ?? size.width,
    height: size.height
  )
}
