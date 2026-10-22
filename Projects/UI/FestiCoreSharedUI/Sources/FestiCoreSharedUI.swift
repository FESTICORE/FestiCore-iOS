//
//  FestiCoreSharedUI.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import FestiCoreDesignSystem

/// A reusable title and content arrangement for feature screens.
public struct FestiCoreSection<Content: View>: View {
  private let title: String
  private let content: Content

  public init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM12) {
      Text(title)
        .festiCoreTextStyle(FestiCoreTypography.baseHeadlineBold)
        .foregroundStyle(Color.festiCore(FestiCoreColor.labelStrong))
      content
    }
  }
}
