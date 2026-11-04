import FestiCoreDesignKit
import SwiftUI
import UIKit

/// 포스터는 시스템 밝기와 무관하게 Figma의 DesignKit Dark 배경색을 사용한다.
enum WidgetPalette {
  static let black = Color(uiColor: FestiCoreSemanticColor.backgroundNormal.uiColor.resolvedColor(
    with: UITraitCollection(userInterfaceStyle: .dark)
  ))
}
