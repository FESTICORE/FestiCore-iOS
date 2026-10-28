//
//  FestiCoreHomeView.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

public struct FestiCoreHomeView: View {
  @Bindable public var store: StoreOf<HomeFeature>

  public init(store: StoreOf<HomeFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 12) {
      Text("FestiCore")
        .font(.largeTitle.bold())
      Text("곧 만나요")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .multilineTextAlignment(.center)
    .accessibilityElement(children: .combine)
  }
}
