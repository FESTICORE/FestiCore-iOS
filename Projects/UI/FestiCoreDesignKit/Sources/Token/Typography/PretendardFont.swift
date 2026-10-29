//
//  PretendardFont.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI

private enum PretendardFontRegistration {
  static let once: Void = PretendardFontFamily.registerFonts()
}

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

  /// 타이포 토큰 하나로 폰트·자간·행간을 적용한다. 체이닝의 기본 진입점.
  func festiCoreFont(_ style: FestiCoreTextStyle) -> some View {
    pretendardFont(family: style.fontFamily, size: style.size)
      .tracking(style.letterSpacing)
      .lineSpacing(style.resolvedLineSpacing)
  }
}

public extension UIFont {
  static func pretendardFontFamily(family: PretendardFontFamily, size: CGFloat) -> UIFont {
    _ = PretendardFontRegistration.once
    return UIFont(name: "PretendardVariable-\(family)", size: size) ?? .systemFont(ofSize: size)
  }
}

public extension Font {
  static func pretendardFontFamily(family: PretendardFontFamily, size: CGFloat) -> Font {
    _ = PretendardFontRegistration.once
    return .custom("PretendardVariable-\(family)", fixedSize: size)
  }
}
