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
  /// - Parameter dismissesOnDimTap: 참이면 딤을 탭할 때 바인딩을 비워 `PresentationAction.dismiss`를 보낸다.
  func fcAlert(
    _ store: Binding<Store<FCAlertState<FCAlertAction>, FCAlertAction>?>,
    dismissesOnDimTap: Bool = false,
    textAlignment: TextAlignment = .leading
  ) -> some View {
    return modifier(FCAlertStoreModifier(
      store: store,
      dismissesOnDimTap: dismissesOnDimTap,
      textAlignment: textAlignment
    ))
  }

  /// 클로저로 동작을 넘기는 다이얼로그를 띄운다. 버튼을 누르면 `item`을 비운다.
  func fcDialog(item: Binding<FCDialogItem?>) -> some View {
    modifier(FCDialogItemModifier(item: item))
  }
}

struct FCAlertStoreModifier: ViewModifier {
  @Binding var store: Store<FCAlertState<FCAlertAction>, FCAlertAction>?
  var dismissesOnDimTap = false
  var textAlignment: TextAlignment = .leading

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
            textAlignment: textAlignment,
            onDimTap: dismissesOnDimTap ? { store = nil } : nil,
            onDismiss: {}
          )
          // Store 인스턴스는 TCA가 재사용할 수 있어 상태의 표시 ID로 구분한다.
          .id(state.presentationID)
        }
      }
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
  }
}
