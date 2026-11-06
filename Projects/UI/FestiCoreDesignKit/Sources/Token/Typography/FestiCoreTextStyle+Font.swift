//
//  FestiCoreTextStyle+Font.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/23/26.
//

import UIKit

public extension FestiCoreTextStyle {
  var resolvedLineSpacing: CGFloat {
    return max(
      0,
      size * lineHeight - resolvedFont.lineHeight
    )
  }

  var resolvedFont: UIFont {
    _ = FestiCoreFontRegistration.once
    switch self {
    case .pointDisplay, .pointHeading, .pointLabel, .pointTitle:
      return UIFont(
        name: "BagelFatOne-Regular",
        size: size
      ) ?? .systemFont(ofSize: size)
    default:
      return UIFont.pretendardFontFamily(
        family: fontFamily,
        size: size
      )
    }
  }
}
