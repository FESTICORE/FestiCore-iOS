//
//  FestiCoreTab.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 상단 밑줄형 탭. 화면 폭을 칸 수로 나눈다.
public struct FestiCoreTab: View {
  @Binding private var selection: Int
  private var items: [String]

  public init(selection: Binding<Int>, items: [String]) {
    self._selection = selection
    self.items = items
  }

  public var body: some View {
    if !items.isEmpty {
      HStack(spacing: .zero) {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
          let isSelected = FestiCoreSelection.isSelected(index: index, selection: selection, count: items.count)

          Button {
            selection = index
          } label: {
            FestiCoreTabItem(item, isSelected: isSelected)
              .frame(maxWidth: .infinity)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
    }
  }
}

// MARK: - 체이닝 설정
public extension FestiCoreTab {
  /// `items` 를 바꾼 사본을 돌려준다.
  func items(_ items: [String]) -> Self {
    var copy = self
    copy.items = items
    return copy
  }
}
