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
    return UIFont.pretendardFontFamily(
      family: fontFamily,
      size: size
    )
  }
}
