//
//  FestiCoreHomeView.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

public struct FestiCoreHomeView: View {
  public init(configurationIsAvailable: Bool) {
    self.configurationIsAvailable = configurationIsAvailable
  }

  private let configurationIsAvailable: Bool

  public var body: some View {
    VStack(spacing: 12) {
      Text("FestiCore")
        .font(.largeTitle.bold())
      Text(configurationIsAvailable ? "곧 만나요" : "설정을 확인해 주세요")
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}
