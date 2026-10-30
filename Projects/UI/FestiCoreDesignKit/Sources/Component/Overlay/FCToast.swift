//
//  FCToast.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 하단 짧은 알림. 탭 바 위에 2초 동안 보인다.
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

    public static func booked(_ message: String = "내가 예매한 페스티벌에 담았어요") -> Item {
      Item(icon: .bookmark16, message: message)
    }

    public static func unbooked(_ message: String = "내가 예매한 페스티벌에서 제외했어요") -> Item {
      Item(icon: .bookmark16, message: message)
    }

    public static func noLink(_ message: String = "예매처 정보가 없습니다") -> Item {
      Item(icon: .circleInfo16, message: message)
    }

    public static func scheduleAdded(_ message: String = "내 일정에 추가됐어요") -> Item {
      Item(icon: .check, message: message)
    }

    public static func scheduleRemoved(_ message: String = "내 일정에서 제외했어요") -> Item {
      Item(icon: .xmark16, message: message)
    }

    public static func followed(_ name: String) -> Item {
      Item(icon: .flag16, message: "\(name)님을 팔로우했습니다")
    }
  }

  private var item: Item

  public init(_ item: Item) {
    self.item = item
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Image(asset: item.icon)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
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

public extension View {
  /// `item`이 있으면 아래쪽에 토스트를 띄우고 `duration` 뒤 자동으로 비운다.
  /// `bottomPadding`은 탭 바 높이만큼 띄울 때 쓴다.
  func fcToast(
    item: Binding<FCToast.Item?>,
    duration: Double = 2,
    bottomPadding: CGFloat = FestiCoreSpacing.paddingP16
  ) -> some View {
    overlay(alignment: .bottom) {
      if let current = item.wrappedValue {
        FCToast(current)
          .padding(.bottom, bottomPadding)
          .transition(.move(edge: .bottom).combined(with: .opacity))
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
    FCToast(.booked())
    FCToast(.unbooked())
    FCToast(.noLink())
    FCToast(.scheduleAdded())
    FCToast(.scheduleRemoved())
    FCToast(.followed("호락호락"))
  }
  .padding(FestiCoreSpacing.paddingP16)
}
