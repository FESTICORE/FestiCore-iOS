//
//  PretendardFontFamily.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import Foundation

public enum PretendardFontFamily {
  case Black
  case Bold
  case ExtraBold
  case ExtraLight
  case Light
  case Medium
  case Regular
  case SemiBold
  case Thin

  public static func registerFonts() {
    var registeredPaths = Set<String>()
    for font in FestiCoreDesignKitFontFamily.allCustomFonts
    where registeredPaths.insert(font.path).inserted {
      font.register()
    }
  }
}
