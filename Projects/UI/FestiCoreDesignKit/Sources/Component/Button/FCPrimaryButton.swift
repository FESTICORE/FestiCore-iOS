//
//  FCPrimaryButton.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

public struct FCPrimaryButton: View {
  private let title: String
  private let isEnabled: Bool
  private let action: () -> Void

  public init(
    _ title: String,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.isEnabled = isEnabled
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Text(title)
        .festiCoreFont(.baseBodyBold)
        .foregroundStyle(FestiCoreSemanticColor.primaryOnPrimary.color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, FestiCoreSpacing.paddingP16)
        .background(FestiCoreSemanticColor.primaryNormal.color)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
    }
    .disabled(!isEnabled)
    // Foundation state.disabled는 요소 전체에 30% opacity를 적용한다.
    .opacity(isEnabled ? 1 : FestiCoreState.disabledOpacity)
  }
}
