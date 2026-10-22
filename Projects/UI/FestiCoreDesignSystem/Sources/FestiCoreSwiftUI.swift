import SwiftUI

public extension Color {
  static func festiCore(_ token: UIColor) -> Color {
    Color(uiColor: token)
  }
}

public extension Text {
  /// Applies the token's font size, weight, and letter spacing.
  func festiCoreTextStyle(_ style: FestiCoreTextStyle) -> Text {
    font(Font(style.font)).tracking(style.letterSpacing)
  }
}
