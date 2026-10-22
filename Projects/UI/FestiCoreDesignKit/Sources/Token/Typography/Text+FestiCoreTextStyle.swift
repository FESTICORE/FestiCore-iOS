//
//  Text+FestiCoreTextStyle.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

public extension View {
  func festiCoreTextStyle(_ style: FestiCoreTextStyle) -> some View {
    let family = PretendardFontFamily(weight: style.weight)
    // 포인트 서체가 제공되기 전까지 Pretendard를 사용한다.
    let font = UIFont.pretendardFontFamily(family: family, size: style.size)

    return self
      .font(Font(font))
      .tracking(style.letterSpacing)
      .lineSpacing(max(0, style.size * style.lineHeight - font.lineHeight))
  }
}
