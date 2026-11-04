import CoreText
import SwiftUI

enum WidgetFont {
  private static let registered: Void = {
    let name = "BagelFatOne-Regular"
    guard let url = Bundle.main.url(
      forResource: name,
      withExtension: "ttf",
      subdirectory: "Resources/Fonts"
    ) ?? Bundle.main.url(
      forResource: name,
      withExtension: "ttf"
    ) else {
      return
    }
    CTFontManagerRegisterFontsForURL(
      url as CFURL,
      .process,
      nil
    )
  }()

  static func bagel(_ size: CGFloat) -> Font {
    _ = registered
    return .custom(
      "BagelFatOne-Regular",
      fixedSize: size
    )
  }
}
