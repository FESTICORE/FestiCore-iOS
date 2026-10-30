//
//  FCCheckOverlay.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 버튼을 누른 직후 잠깐 보이는 전체 화면 확인
public struct FCCheckOverlay: View {
  public struct Item: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String

    public init(
      title: String,
      message: String
    ) {
      self.title = title
      self.message = message
    }
  }

  private var item: Item

  public init(_ item: Item) {
    self.item = item
  }

  public var body: some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      FCCheckBadge()
        .padding(.bottom, FestiCoreSpacing.paddingP8)
      Text(item.title)
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
      Text(item.message)
        .festiCoreFont(.baseCalloutRegular)
        .foregroundStyle(FestiCoreSemanticColor.staticWhite.color.opacity(Metric.messageOpacity))
    }
    .multilineTextAlignment(.center)
    .padding(FestiCoreSpacing.paddingP24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.staticBlack.color.opacity(Metric.dimOpacity))
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isModal)
  }
}

public extension View {
  /// `item`이 있으면 확인 화면을 띄우고 햅틱을 준 뒤 `duration` 뒤 자동으로 비운다.
  func fcCheckOverlay(
    item: Binding<FCCheckOverlay.Item?>,
    duration: Double = 1
  ) -> some View {
    overlay {
      if let current = item.wrappedValue {
        FCCheckOverlay(current)
          .ignoresSafeArea()
          .transition(.opacity)
          .task(id: current.id) {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, item.wrappedValue?.id == current.id else { return }
            item.wrappedValue = nil
          }
      }
    }
    .sensoryFeedback(.success, trigger: item.wrappedValue?.id) { _, new in new != nil }
    .animation(.easeOut(duration: Metric.duration), value: item.wrappedValue)
  }
}

private enum Metric {
  static let dimOpacity = 0.8
  static let messageOpacity = 0.8
  static let duration = 0.2
}

#Preview {
  FCCheckOverlay(
    FCCheckOverlay.Item(
      title: "리벳 스테이지 중앙으로 바꿨어요",
      message: "팔로워에게 알렸어요"
    )
  )
}
