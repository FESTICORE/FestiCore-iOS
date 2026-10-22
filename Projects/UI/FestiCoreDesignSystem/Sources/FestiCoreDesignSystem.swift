//
//  FestiCoreDesignSystem.swift
//  FestiCoreDesignSystem
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

public struct FestiCorePrimaryButton: View {
  private let title: String
  private let isEnabled: Bool
  private let action: () -> Void

  public init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
    self.title = title
    self.isEnabled = isEnabled
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Text(title)
        .festiCoreTextStyle(FestiCoreTypography.baseBodyBold)
        .foregroundStyle(Color.festiCore(FestiCoreColor.primaryOnPrimary))
        .frame(maxWidth: .infinity)
        .padding(.vertical, FestiCoreSpacing.paddingP16)
        .background(Color.festiCore(FestiCoreColor.primaryNormal))
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
    }
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.5)
  }
}

public struct FestiCoreDivider: View {
  private let thickness: CGFloat

  public init(thickness: CGFloat = 1) {
    self.thickness = thickness
  }

  public var body: some View {
    Color.festiCore(FestiCoreColor.lineNormal)
      .frame(height: thickness)
      .accessibilityHidden(true)
  }
}
