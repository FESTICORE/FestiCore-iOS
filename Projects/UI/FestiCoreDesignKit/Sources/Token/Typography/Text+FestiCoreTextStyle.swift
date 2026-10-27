//
//  Text+FestiCoreTextStyle.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

public extension View {
  func festiCoreTextStyle(_ style: FestiCoreTextStyle) -> some View {
    return self
      .pretendardFont(family: style.fontFamily, size: style.size)
      .tracking(style.letterSpacing)
      .lineSpacing(style.resolvedLineSpacing)
  }
}
