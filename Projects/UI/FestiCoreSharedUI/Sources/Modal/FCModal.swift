//
//  FCModal.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

public extension View {
  /// 하단에서 올라오는 모달(바텀시트) 오버레이.
  /// 손잡이·모서리·딤·끌어서 닫기는 DesignKit 바텀시트를 그대로 쓴다.
  /// - Parameters:
  ///   - store: `@Presents` 스코프 바인딩 (nil 이면 미표시). 끌거나 딤을 눌러 닫으면 `.dismiss`를 보낸다.
  ///   - height: 시트 높이.
  ///   - showsGrabber: 위쪽 손잡이 표시 여부.
  ///   - content: 표시할 모달 뷰 (스코프된 스토어를 받음).
  func fcModal<State, Action>(
    _ store: Binding<Store<State, Action>?>,
    height: FCSheetHeight = .auto,
    showsGrabber: Bool = true,
    @ViewBuilder content: @escaping (Store<State, Action>) -> some View
  ) -> some View {
    presentFCSheet(
      item: Binding(
        get: { store.wrappedValue.map(FCModalItem.init) },
        set: { if $0 == nil { store.wrappedValue = nil } }
      ),
      height: height,
      showsGrabber: showsGrabber
    ) { item in
      content(item.store)
    }
  }
}

public extension View {
  /// `fcModal`과 같고, 시트 위쪽 가장자리에 붙어 함께 움직이는 `accessory`(토스트 등)를 더한다.
  /// 닫기가 시작되면 `accessory`는 바로 감춰진다.
  func fcModal<State, Action>(
    _ store: Binding<Store<State, Action>?>,
    height: FCSheetHeight = .auto,
    showsGrabber: Bool = true,
    @ViewBuilder content: @escaping (Store<State, Action>) -> some View,
    @ViewBuilder accessory: @escaping (Store<State, Action>) -> some View
  ) -> some View {
    presentFCSheet(
      item: Binding(
        get: { store.wrappedValue.map(FCModalItem.init) },
        set: { if $0 == nil { store.wrappedValue = nil } }
      ),
      height: height,
      showsGrabber: showsGrabber
    ) { item in
      content(item.store)
    } accessory: { item in
      accessory(item.store)
    }
  }
}

/// 바텀시트가 표시 대상을 구분할 수 있게 스토어를 감싼다.
private struct FCModalItem<State, Action>: Identifiable, Equatable {
  let store: Store<State, Action>

  var id: ObjectIdentifier { ObjectIdentifier(store) }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}
