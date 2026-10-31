//
//  FCAlertModifiers.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestiCoreAnimation
import FestiCoreDesignKit
import SwiftUI

public extension View {
  /// Feature의 `@Presents` 다이얼로그 상태를 가운데 확인 다이얼로그로 띄운다.
  func fcAlert(
    _ store: Binding<Store<FCAlertState<FCAlertAction>, FCAlertAction>?>
  ) -> some View {
    modifier(FCAlertStoreModifier(store: store))
  }

  /// 클로저로 동작을 넘기는 다이얼로그를 띄운다. 버튼을 누르면 `item`을 비운다.
  func fcDialog(item: Binding<FCDialogItem?>) -> some View {
    modifier(FCDialogItemModifier(item: item))
  }
}

struct FCAlertStoreModifier: ViewModifier {
  @Binding var store: Store<FCAlertState<FCAlertAction>, FCAlertAction>?

  func body(content: Content) -> some View {
    content
      .overlay {
        if let alertStore = store {
          let state = alertStore.withState { $0 }
          FCDialogOverlay(
            item: FCDialogItem(
              title: state.title,
              message: state.message,
              confirmTitle: state.confirmTitle,
              cancelTitle: state.cancelTitle,
              onConfirm: { alertStore.send(.confirmTapped) },
              onCancel: { alertStore.send(.cancelTapped) }
            ),
            onDismiss: {}
          )
          // Store 인스턴스는 TCA가 재사용할 수 있어 상태의 표시 ID로 구분한다.
          .id(state.presentationID)
        }
      }
      .animation(.fcModal, value: store?.withState(\.presentationID))
  }
}

struct FCDialogItemModifier: ViewModifier {
  @Binding var item: FCDialogItem?

  func body(content: Content) -> some View {
    content
      .overlay {
        if let current = item {
          FCDialogOverlay(
            item: current,
            onDismiss: { item = nil }
          )
          .id(current.id)
        }
      }
      .animation(.fcModal, value: item)
  }
}

/// 딤 배경 위에 다이얼로그를 띄운다. 딤이 밝아지며 다이얼로그가 아래에서 올라오고, 닫힐 때는 함께 사라진다.
public struct FCDialogOverlay: View {
  @State private var isContentVisible = false
  private let item: FCDialogItem
  private let dismissesOnDimTap: Bool
  private let onDismiss: () -> Void

  /// - Parameters:
  ///   - dismissesOnDimTap: 참이면 딤을 탭할 때 `onDismiss`를 부른다.
  public init(
    item: FCDialogItem,
    dismissesOnDimTap: Bool = false,
    onDismiss: @escaping () -> Void
  ) {
    self.item = item
    self.dismissesOnDimTap = dismissesOnDimTap
    self.onDismiss = onDismiss
  }

  public var body: some View {
    ZStack {
      FestiCoreSemanticColor.materialDimmer.color
        .opacity(isContentVisible ? 1 : 0)
        .ignoresSafeArea()
        .onTapGesture {
          if dismissesOnDimTap { onDismiss() }
        }
      FCDialog(
        item,
        onDismiss: onDismiss
      )
      .offset(y: isContentVisible ? 0 : Metric.appearOffset)
      .opacity(isContentVisible ? 1 : 0)
    }
    .transition(.opacity.animation(.fcModal))
    .onAppear {
      withAnimation(.fcModal) {
        isContentVisible = true
      }
    }
  }
}

private enum Metric {
  static let appearOffset: CGFloat = 120
}
