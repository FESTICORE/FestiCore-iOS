//
//  FCToast.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 화면 상단에 표시하는 짧은 알림.
public struct FCToast: View {
  /// 토스트 한 건. 같은 문구도 새로 띄울 수 있게 `id`로 구분한다.
  public struct Item: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let icon: ImageAsset
    public let message: String

    public init(
      icon: ImageAsset,
      message: String
    ) {
      self.icon = icon
      self.message = message
    }
  }

  private var item: Item
  private var iconColor = FestiCoreSemanticColor.staticWhite.color

  public init(_ item: Item) {
    self.item = item
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Image(asset: item.icon)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .foregroundStyle(iconColor)
        .accessibilityHidden(true)
      Text(item.message)
        .festiCoreFont(.baseFootnoteMedium)
    }
    .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.staticalphaBlack80.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
    .accessibilityElement(children: .combine)
  }
}

public extension FCToast {
  /// 아이콘 색을 바꾼 사본을 돌려준다.
  func iconColor(_ color: Color) -> Self {
    var copy = self
    copy.iconColor = color
    return copy
  }
}

public extension View {
  /// `item`이 있으면 위쪽에 토스트를 띄우고 `duration` 뒤 자동으로 비운다.
  func fcToast(
    item: Binding<FCToast.Item?>,
    duration: Double = 2,
    topPadding: CGFloat = 30
  ) -> some View {
    overlay(alignment: .top) {
      if let current = item.wrappedValue {
        FCToast(current)
          .padding(
            .top,
            topPadding
          )
          .transition(.move(edge: .top).combined(with: .opacity))
          .task(id: current.id) {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, item.wrappedValue?.id == current.id else { return }
            item.wrappedValue = nil
          }
      }
    }
    .animation(.easeOut(duration: Metric.duration), value: item.wrappedValue)
  }
}

private enum Metric {
  static let iconSize: CGFloat = 16
  static let duration: Double = 0.25
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCToast(FCToast.Item(icon: .check, message: "내 일정에 추가됐어요"))
    FCToast(FCToast.Item(icon: .circleInfo16, message: "예매처 정보가 없습니다"))
  }
  .padding(FestiCoreSpacing.paddingP16)
}
