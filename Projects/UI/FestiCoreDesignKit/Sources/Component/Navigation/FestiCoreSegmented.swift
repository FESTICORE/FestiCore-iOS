//
//  FestiCoreSegmented.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 2~3개 보기 전환(날짜, 보기 방식 등). 선택 칸은 Fill/Selected.
public struct FestiCoreSegmented: View {
  @Binding private var selection: Int
  private var items: [String]

  @Namespace private var selectionNamespace

  public init(selection: Binding<Int>, items: [String]) {
    self._selection = selection
    self.items = items
  }

  public var body: some View {
    if !items.isEmpty {
      HStack(spacing: .zero) {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
          segment(item, index: index)
        }
      }
      .padding(FestiCoreSpacing.paddingP4)
      .frame(height: Metric.height)
      .background(
        FestiCoreSemanticColor.fillNormal.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
      )
    }
  }

  private func segment(_ item: String, index: Int) -> some View {
    let isSelected = FestiCoreSelection.isSelected(index: index, selection: selection, count: items.count)

    return Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
        selection = index
      }
    } label: {
      Text(item)
        .festiCoreTextStyle(isSelected ? .baseSubheadlineBold : .baseSubheadlineMedium)
        .foregroundStyle(
          isSelected
            ? FestiCoreSemanticColor.labelNormal.color
            : FestiCoreSemanticColor.labelAssistive.color
        )
        .lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          if isSelected {
            RoundedRectangle(cornerRadius: FestiCoreRadius.r8)
              .fill(FestiCoreSemanticColor.fillSelected.color)
              .shadow(color: FestiCoreSemanticColor.staticBlack.color.opacity(Metric.shadowOpacity), radius: Metric.shadowRadius)
              .matchedGeometryEffect(id: "selection", in: selectionNamespace)
          }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - 체이닝 설정
public extension FestiCoreSegmented {
  /// `items` 를 바꾼 사본을 돌려준다.
  func items(_ items: [String]) -> Self {
    var copy = self
    copy.items = items
    return copy
  }
}

private extension FestiCoreSegmented {
  enum Metric {
    static let height: CGFloat = 40
    static let shadowOpacity: Double = 0.08
    static let shadowRadius: CGFloat = 3
  }
}
