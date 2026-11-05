//
//  FCConfirmationPopupView.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreAnimation
import FestiCoreDesignKit
import SwiftUI

/// 딤 배경 위에 다이얼로그를 띄운다. 딤이 밝아지며 다이얼로그가 아래에서 올라오고, 닫힐 때는 함께 사라진다.
public struct FCDialogOverlay: View {
  @State private var isContentVisible = false
  /// 첫 입력을 처리했는지. 닫히는 동안 늦게 들어온 탭이 동작을 다시 실행하지 않게 한다.
  @State private var isHandled = false
  private let item: FCDialogItem
  private let textAlignment: TextAlignment
  private let dismissesOnDimTap: Bool
  private let onDimTap: (() -> Void)?
  private let onDismiss: () -> Void

  /// - Parameters:
  ///   - dismissesOnDimTap: 참이면 딤을 탭할 때 `onDismiss`를 부른다.
  ///   - onDimTap: 버튼과 다른 닫기 동작이 필요할 때 딤 탭에서 부른다. `dismissesOnDimTap`보다 우선한다.
  public init(
    item: FCDialogItem,
    textAlignment: TextAlignment = .leading,
    dismissesOnDimTap: Bool = false,
    onDimTap: (() -> Void)? = nil,
    onDismiss: @escaping () -> Void
  ) {
    self.item = item
    self.textAlignment = textAlignment
    self.dismissesOnDimTap = dismissesOnDimTap
    self.onDimTap = onDimTap
    self.onDismiss = onDismiss
  }

  public var body: some View {
    ZStack {
      FestiCoreSemanticColor.materialDimmer.color
        .opacity(isContentVisible ? 1 : 0)
        .ignoresSafeArea()
        .onTapGesture {
          guard !isHandled else { return }
          if let onDimTap {
            isHandled = true
            onDimTap()
          } else if dismissesOnDimTap {
            isHandled = true
            onDismiss()
          }
        }
      FCDialog(
        handledOnce(item),
        onDismiss: onDismiss
      )
      .textAlignment(textAlignment)
      .offset(y: isContentVisible ? 0 : Metric.appearOffset)
      .opacity(isContentVisible ? 1 : 0)
    }
    .allowsHitTesting(!isHandled)
    .transition(.opacity.animation(.fcModal))
    .onAppear {
      withAnimation(.fcModal) {
        isContentVisible = true
      }
    }
  }
}

private extension FCDialogOverlay {
  enum Metric {
    /// 다이얼로그가 올라오기 시작하는 아래쪽 거리.
    static let appearOffset: CGFloat = 120
  }

  /// 버튼 동작이 한 번만 실행되도록 감싼다.
  func handledOnce(_ item: FCDialogItem) -> FCDialogItem {
    FCDialogItem(
      title: item.title,
      message: item.message,
      confirmTitle: item.confirmTitle,
      cancelTitle: item.cancelTitle,
      onConfirm: {
        guard !isHandled else { return }
        isHandled = true
        item.onConfirm()
      },
      onCancel: {
        guard !isHandled else { return }
        isHandled = true
        item.onCancel()
      }
    )
  }
}
