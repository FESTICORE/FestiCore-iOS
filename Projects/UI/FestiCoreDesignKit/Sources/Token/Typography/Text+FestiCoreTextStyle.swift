//
//  Text+FestiCoreTextStyle.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

public extension View {
  func festiCoreTextStyle(_ style: FestiCoreTextStyle) -> some View {
    let font = style.resolvedFont

    return self
      .font(Font(font))
      // 생성된 자간은 원본 em 값에 fontSize를 곱한 pt 값이다.
      .tracking(style.letterSpacing)
      // 토큰의 행간 배수에서 실제 서체 높이를 빼 SwiftUI 행간으로 바꾼다.
      .lineSpacing(style.resolvedLineSpacing)
  }
}
