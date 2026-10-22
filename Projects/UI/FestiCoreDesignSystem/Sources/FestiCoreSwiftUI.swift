import SwiftUI

public extension Color {
  static func festiCore(_ token: UIColor) -> Color {
    Color(uiColor: token)
  }
}

public extension Text {
  /// Applies the token's font size, weight, line height, and letter spacing.
  func festiCoreTextStyle(_ style: FestiCoreTextStyle) -> some View {
    font(Font(style.font)).tracking(style.letterSpacing)
      .lineSpacing(style.lineSpacing)
  }
}
