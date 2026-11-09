//
//  FCTab.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 상단 밑줄형 탭. 화면 폭을 칸 수로 나눈다.
/// 밑줄은 하나만 그려 선택한 칸으로 옮긴다. 본문을 스와이프해 선택이 바뀌어도 같이 따라간다.
public struct FCTab: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Binding private var selection: Int
  private var items: [String]
  private var indicatorColor = FestiCoreSemanticColor.labelNormal.color

  public init(
    selection: Binding<Int>,
    items: [String]
  ) {
    self._selection = selection
    self.items = items
  }

  public var body: some View {
    if !items.isEmpty {
      HStack(spacing: .zero) {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
          let isSelected = FCSelection.isSelected(index: index, selection: selection, count: items.count)

          Button {
            selection = index
          } label: {
            // 칸마다 밑줄을 그리지 않고 아래 indicator 하나를 옮긴다.
            FCTabItem(
              item,
              isSelected: isSelected
            )
              .indicatorColor(.clear)
              .frame(maxWidth: .infinity)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
      .overlay(alignment: .bottomLeading) {
        indicator
      }
    }
  }
}

private extension FCTab {
  /// 범위 안의 선택 칸. 범위를 벗어나면 밑줄을 그리지 않는다.
  var selectedIndex: Int? {
    return (0..<items.count).first { index in
      return FCSelection.isSelected(
        index: index,
        selection: selection,
        count: items.count
      )
    }
  }

  /// FCTabItem 밑줄과 같은 위치·크기(칸 폭에서 좌우 여백을 뺀 2pt 막대)로 선택 칸을 따라 움직인다.
  var indicator: some View {
    return GeometryReader { proxy in
      if let selectedIndex {
        let width = proxy.size.width / CGFloat(items.count)
        UnevenRoundedRectangle(
          topLeadingRadius: Metric.indicatorRadius,
          topTrailingRadius: Metric.indicatorRadius
        )
        .fill(indicatorColor)
        .frame(
          width: max(
            0,
            width - FestiCoreSpacing.paddingP16 * 2
          ),
          height: Metric.indicatorHeight
        )
        .offset(
          x: width * CGFloat(selectedIndex) + FestiCoreSpacing.paddingP16,
          y: proxy.size.height - Metric.indicatorHeight
        )
        .animation(
          reduceMotion ? nil : .easeOut(duration: 0.2),
          value: selectedIndex
        )
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  enum Metric {
    static let indicatorHeight: CGFloat = 2
    static let indicatorRadius: CGFloat = 2
  }
}

// MARK: - 체이닝 설정
public extension FCTab {
  /// `items` 를 바꾼 사본을 돌려준다.
  func items(_ items: [String]) -> Self {
    var copy = self
    copy.items = items
    return copy
  }

  /// 선택된 탭의 밑줄 색을 바꾼 사본을 돌려준다.
  func indicatorColor(_ color: Color) -> Self {
    var copy = self
    copy.indicatorColor = color
    return copy
  }
}

#Preview {
  @Previewable
  @State var selection = 0

  FCTab(
    selection: $selection,
    items: ["1일차", "2일차", "3일차"]
  )
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
