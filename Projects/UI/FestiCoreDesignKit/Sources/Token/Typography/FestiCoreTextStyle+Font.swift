//
//  FestiCoreTextStyle+Font.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/23/26.
//

import UIKit

public extension FestiCoreTextStyle {
  var resolvedLineSpacing: CGFloat {
    max(0, size * lineHeight - resolvedFont.lineHeight)
  }

  var resolvedFont: UIFont {
    if fontFamily == "Bagel Fat One" {
      // Tuist가 번들한 두 서체는 한 번에 등록된다.
      PretendardFontFamily.registerFonts()
      return UIFont(name: "BagelFatOne-Regular", size: size) ?? .systemFont(ofSize: size)
    }

    return UIFont.pretendardFontFamily(
      family: PretendardFontFamily(weight: weight),
      size: size
    )
  }
}
