//
//  FestiCoreDivider.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

public struct FestiCoreDivider: View {
  private let thickness: CGFloat

  public init(thickness: CGFloat = 1) {
    self.thickness = thickness
  }

  public var body: some View {
    Color.lineNormal
      .frame(height: thickness)
      .accessibilityHidden(true)
  }
}
