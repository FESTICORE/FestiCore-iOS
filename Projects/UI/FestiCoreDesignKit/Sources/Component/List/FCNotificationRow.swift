//
//  FCNotificationRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 알림함 한 줄. 읽음·안 읽음은 줄 바탕으로 구분하고, 편집 모드에서는 선택 체크를 보인다.
public struct FCNotificationRow: View {
  private var title: String
  private var message: String
  private var time: String
  private var isRead: Bool
  private(set) var icon: ImageAsset = .bell16
  private(set) var isEditing = false
  private(set) var isSelected = false

  public init(
    title: String,
    message: String,
    time: String,
    isRead: Bool
  ) {
    self.title = title
    self.message = message
    self.time = time
    self.isRead = isRead
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      if isEditing {
        FCCheckCircle(isChecked: isSelected)
      }
      Image(asset: icon)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .frame(width: Metric.iconWrapSize, height: Metric.iconWrapSize)
        .background(FestiCoreSemanticColor.fillNormal.color, in: Circle())
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          Text(title)
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(time)
            .festiCoreFont(.baseCaption1Regular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
        Text(message)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      .lineLimit(1)
    }
    .padding(FestiCoreSpacing.paddingP16)
    .background(isRead ? FestiCoreSemanticColor.backgroundElevated.color : FestiCoreSemanticColor.accentBackgroundLime.color)
    .accessibilityElement(children: .combine)
    .accessibilityValue(isRead ? "읽음" : "안 읽음")
    .accessibilityAddTraits(isEditing && isSelected ? .isSelected : [])
  }
}

// MARK: - 체이닝 설정

public extension FCNotificationRow {
  /// 왼쪽 아이콘을 바꾼 사본을 돌려준다.
  func icon(_ icon: ImageAsset) -> Self {
    var copy = self
    copy.icon = icon
    return copy
  }

  /// 편집 모드와 선택 여부를 바꾼 사본을 돌려준다.
  func editing(
    _ isEditing: Bool,
    isSelected: Bool = false
  ) -> Self {
    var copy = self
    copy.isEditing = isEditing
    copy.isSelected = isSelected
    return copy
  }
}

private extension FCNotificationRow {
  enum Metric {
    static let iconWrapSize: CGFloat = 40
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCNotificationRow(
      title: "노이즈캔디 10분 후 시작",
      message: "리벳 스테이지 · 15:40",
      time: "2분 전",
      isRead: false
    )
    FCNotificationRow(
      title: "노이즈캔디 10분 후 시작",
      message: "리벳 스테이지 · 15:40",
      time: "2분 전",
      isRead: true
    )
    .editing(true, isSelected: true)
  }
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
