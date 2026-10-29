//
//  FCSortMenu.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 정렬 드롭다운. `FCSortButton` 아래 오른쪽 정렬로 띄우고, 바깥을 누르면 닫는 처리는 화면이 맡는다.
public struct FCSortMenu: View {
  @Binding private var selection: Int
  private var items: [String]

  public init(selection: Binding<Int>, items: [String]) {
    _selection = selection
    self.items = items
  }

  public var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        Button {
          selection = index
        } label: {
          FCMenuItem(item)
            .isSelected(FCSelection.isSelected(index: index, selection: selection, count: items.count))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, FestiCoreSpacing.paddingP4)
    .frame(width: Metric.width)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: shape)
    .overlay {
      shape.stroke(FestiCoreSemanticColor.lineNormal.color, lineWidth: Metric.borderWidth)
    }
    .shadow(
      color: FestiCoreSemanticColor.staticBlack.color.opacity(Metric.shadowOpacity),
      radius: Metric.shadowRadius,
      y: Metric.shadowY
    )
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
  }
}

private extension FCSortMenu {
  enum Metric {
    static let width: CGFloat = 200
    static let borderWidth: CGFloat = 1
    static let shadowOpacity: Double = 0.12
    // Figma blur 24는 SwiftUI radius 12에 해당한다.
    static let shadowRadius: CGFloat = 12
    static let shadowY: CGFloat = 8
  }
}

#Preview {
  @Previewable
  @State var selection = 0

  FCSortMenu(selection: $selection, items: ["활동 중 순", "팔로워 많은 순", "최근 업데이트 순", "새로 생긴 순"])
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
}
