//
//  PretendardFont.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

public struct PretendardFont: ViewModifier {
  public let family: PretendardFontFamily
  public let size: CGFloat

  public func body(content: Content) -> some View {
    content.font(.pretendardFontFamily(family: family, size: size))
  }
}

public extension View {
  func pretendardFont(family: PretendardFontFamily, size: CGFloat) -> some View {
    modifier(PretendardFont(family: family, size: size))
  }
}

public extension UIFont {
  static func pretendardFontFamily(family: PretendardFontFamily, size: CGFloat) -> UIFont {
    PretendardFontFamily.registerFonts()
    return UIFont(name: family.postScriptName, size: size) ?? .systemFont(ofSize: size)
  }
}

public extension Font {
  static func pretendardFontFamily(family: PretendardFontFamily, size: CGFloat) -> Font {
    PretendardFontFamily.registerFonts()
    return .custom(family.postScriptName, size: size)
  }
}
