//
//  FCDialog.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 확인 다이얼로그에 띄울 내용. 되돌리기 어려운 동작 전에 띄우고 되돌리는 방법을 함께 적는다.
public struct FCDialogItem: Identifiable, Equatable {
  public let id = UUID()
  public let title: String
  public let message: String
  public let confirmTitle: String
  public let cancelTitle: String
  public let onConfirm: () -> Void
  public let onCancel: () -> Void

  public init(
    title: String,
    message: String,
    confirmTitle: String = "확인",
    cancelTitle: String = "취소",
    onConfirm: @escaping () -> Void,
    onCancel: @escaping () -> Void = {}
  ) {
    self.title = title
    self.message = message
    self.confirmTitle = confirmTitle
    self.cancelTitle = cancelTitle
    self.onConfirm = onConfirm
    self.onCancel = onCancel
  }

  public static func == (lhs: FCDialogItem, rhs: FCDialogItem) -> Bool {
    lhs.id == rhs.id
  }
}

/// 가운데 확인 모달 카드.
public struct FCDialog: View {
  private var item: FCDialogItem
  private var onDismiss: () -> Void

  public init(
    _ item: FCDialogItem,
    onDismiss: @escaping () -> Void
  ) {
    self.item = item
    self.onDismiss = onDismiss
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        Text(item.title)
          .festiCoreFont(.baseBodyBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityAddTraits(.isHeader)
        Text(item.message)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        FCButton(item.cancelTitle) {
          item.onCancel()
          onDismiss()
        }
        .style(.secondary)
        .size(.medium)
        .isFullWidth(true)
        FCButton(item.confirmTitle) {
          item.onConfirm()
          onDismiss()
        }
        .size(.medium)
        .isFullWidth(true)
      }
    }
    .padding(.top, FestiCoreSpacing.paddingP24)
    .padding([.horizontal, .bottom], FestiCoreSpacing.paddingP20)
    .frame(width: Metric.width)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r20))
    .accessibilityAddTraits(.isModal)
  }
}

private enum Metric {
  static let width: CGFloat = 311
}

#Preview {
  FCDialog(
    FCDialogItem(
      title: "이 안내를 숨길까요?",
      message: "마이 > 설정에서 다시 켤 수 있어요.",
      onConfirm: {}
    ),
    onDismiss: {}
  )
  .padding(FestiCoreSpacing.paddingP24)
  .background(FestiCoreSemanticColor.materialDimmer.color)
}
