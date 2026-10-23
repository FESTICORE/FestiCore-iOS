//
//  FestiCoreHomeView.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

public struct FestiCoreHomeView: View {
  public init(store: StoreOf<HomeFeature>) {
    self.store = store
  }

  private let store: StoreOf<HomeFeature>

  public var body: some View {
    VStack(spacing: 12) {
      Text("FestiCore")
        .font(.largeTitle.bold())
      Text(store.configurationIsAvailable ? "곧 만나요" : "설정을 확인해 주세요")
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}
