//
//  FCConsentAll.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 약관 전체 동의. 누르면 아래 `FCConsentRow`를 전부 체크하거나 해제하는 처리는 화면이 맡는다.
public struct FCConsentAll: View {
  private var label: String
  private var isChecked: Bool
  private var action: () -> Void

  public init(_ label: String = "전체 동의", isChecked: Bool, action: @escaping () -> Void) {
    self.label = label
    self.isChecked = isChecked
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        FCCheckCircle(isChecked: isChecked)
        Text(label)
          .festiCoreFont(.baseBodyBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(FestiCoreSpacing.paddingP16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isChecked ? .isSelected : [])
  }
}

#Preview {
  VStack(spacing: 0) {
    FCConsentAll(isChecked: true) {}
    FCConsentAll(isChecked: false) {}
  }
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
