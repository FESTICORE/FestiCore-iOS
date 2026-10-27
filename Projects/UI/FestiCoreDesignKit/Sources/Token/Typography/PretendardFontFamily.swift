//
//  PretendardFontFamily.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import UIKit

public enum PretendardFontFamily {
  case black
  case bold
  case extraBold
  case extraLight
  case light
  case medium
  case regular
  case semiBold
  case thin

  public static func registerFonts() {
    _ = registration
  }

  private static let registration: Void = {
    var registeredPaths = Set<String>()
    // 생성된 폰트 등록 목록에서 같은 경로는 한 번만 등록한다.
    for font in FestiCoreDesignKitFontFamily.allCustomFonts
    where registeredPaths.insert(font.path).inserted {
      font.register()
    }
  }()

  init(weight: UIFont.Weight) {
    switch weight {
    case .black: self = .black
    case .heavy: self = .extraBold
    case .bold: self = .bold
    case .semibold: self = .semiBold
    case .medium: self = .medium
    case .light: self = .light
    case .ultraLight: self = .extraLight
    default: self = .regular
    }
  }

  var postScriptName: String {
    switch self {
    case .black: "PretendardVariable-Black"
    case .bold: "PretendardVariable-Bold"
    case .extraBold: "PretendardVariable-ExtraBold"
    case .extraLight: "PretendardVariable-ExtraLight"
    case .light: "PretendardVariable-Light"
    case .medium: "PretendardVariable-Medium"
    case .regular: "PretendardVariable-Regular"
    case .semiBold: "PretendardVariable-SemiBold"
    case .thin: "PretendardVariable-Thin"
    }
  }
}
