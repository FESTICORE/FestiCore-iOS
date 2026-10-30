//
//  FCAlertModifiers.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
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
          FCAlertContainer(
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
        }
      }
      .animation(
        .easeOut(duration: FCAlertMetric.duration),
        value: store != nil
      )
  }
}

struct FCDialogItemModifier: ViewModifier {
  @Binding var item: FCDialogItem?

  func body(content: Content) -> some View {
    content
      .overlay {
        if let current = item {
          FCAlertContainer(
            item: current,
            onDismiss: { item = nil }
          )
        }
      }
      .animation(
        .easeOut(duration: FCAlertMetric.duration),
        value: item
      )
  }
}

/// 딤 배경 위에 다이얼로그를 띄운다.
struct FCAlertContainer: View {
  let item: FCDialogItem
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      FestiCoreSemanticColor.materialDimmer.color
        .ignoresSafeArea()
      FCDialog(
        item,
        onDismiss: onDismiss
      )
      .transition(.scale(scale: FCAlertMetric.appearScale).combined(with: .opacity))
    }
    .transition(.opacity)
  }
}

private enum FCAlertMetric {
  static let appearScale: CGFloat = 0.95
  static let duration: Double = 0.2
}
