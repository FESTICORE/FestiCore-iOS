import SwiftUI

/// 콘텐츠 너비에 맞춰 항목을 배치하고 화면 폭에서 다음 줄로 넘긴다.
public struct FCFlowLayout<Content: View>: View {
  private let content: Content
  private var itemSpacing = FestiCoreSpacing.paddingP8

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    FlowLayout(spacing: itemSpacing) {
      content
    }
  }
}

// MARK: - 체이닝 설정

public extension FCFlowLayout {
  func spacing(_ spacing: CGFloat) -> Self {
    var copy = self
    copy.itemSpacing = spacing
    return copy
  }
}

private struct FlowLayout: Layout {
  let spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
    let height = rows.reduce(CGFloat.zero) { $0 + $1.height }
      + spacing * CGFloat(max(rows.count - 1, 0))
    return CGSize(width: proposal.width ?? (rows.map(\.width).max() ?? 0), height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in arrange(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for item in row.items {
        subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
        x += item.size.width + spacing
      }
      y += row.height + spacing
    }
  }
}

private extension FlowLayout {
  struct Item {
    let index: Int
    let size: CGSize
  }

  struct Row {
    var items: [Item] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
    guard !subviews.isEmpty else { return [] }
    var rows = [Row()]
    let availableWidth = max(width, 0)
    for index in subviews.indices {
      let intrinsic = subviews[index].sizeThatFits(.unspecified)
      let proposedWidth = min(intrinsic.width, availableWidth)
      let measured = subviews[index].sizeThatFits(ProposedViewSize(width: proposedWidth, height: nil))
      let size = CGSize(width: min(measured.width, availableWidth), height: measured.height)
      var row = rows.removeLast()
      let needed = row.items.isEmpty ? size.width : row.width + spacing + size.width
      if needed > availableWidth, !row.items.isEmpty {
        rows.append(row)
        row = Row()
      }
      row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
      row.height = max(row.height, size.height)
      row.items.append(Item(index: index, size: size))
      rows.append(row)
    }
    return rows
  }
}
