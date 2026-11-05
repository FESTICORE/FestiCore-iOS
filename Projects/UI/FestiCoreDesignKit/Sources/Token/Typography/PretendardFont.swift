//
//  PretendardFont.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

enum FestiCoreFontRegistration {
  static let once: Void = PretendardFontFamily.registerFonts()
}

public struct PretendardFont: ViewModifier {
  public let family: PretendardFontFamily
  public let size: CGFloat

  public func body(content: Content) -> some View {
    return content.font(.pretendardFontFamily(
      family: family,
      size: size
    ))
  }
}

public extension View {
  func pretendardFont(
    family: PretendardFontFamily,
    size: CGFloat
  ) -> some View {
    return modifier(PretendardFont(
      family: family,
      size: size
    ))
  }

  /// 타이포 토큰 하나로 폰트·자간·행간을 적용한다. 체이닝의 기본 진입점.
  func festiCoreFont(_ style: FestiCoreTextStyle) -> some View {
    return font(Font(style.resolvedFont))
      .tracking(style.letterSpacing)
      .lineSpacing(style.resolvedLineSpacing)
  }
}

public extension UIFont {
  static func pretendardFontFamily(
    family: PretendardFontFamily,
    size: CGFloat
  ) -> UIFont {
    _ = FestiCoreFontRegistration.once
    return UIFont(
      name: "PretendardVariable-\(family)",
      size: size
    ) ?? .systemFont(ofSize: size)
  }
}

public extension Font {
  static func pretendardFontFamily(
    family: PretendardFontFamily,
    size: CGFloat
  ) -> Font {
    _ = FestiCoreFontRegistration.once
    return .custom(
      "PretendardVariable-\(family)",
      fixedSize: size
    )
  }
}
