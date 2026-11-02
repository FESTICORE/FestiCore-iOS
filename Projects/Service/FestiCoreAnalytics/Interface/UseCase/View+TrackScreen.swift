//
//  View+TrackScreen.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import SwiftUI

public extension View {
  /// 화면이 나타날 때마다 `screenView` 이벤트를 보낸다.
  func trackScreen(_ screen: AnalyticsScreen) -> some View {
    modifier(AnalyticsScreenModifier(screen: screen))
  }
}

private struct AnalyticsScreenModifier: ViewModifier {
  let screen: AnalyticsScreen
  @Dependency(\.analyticsUseCase) private var analyticsUseCase

  func body(content: Content) -> some View {
    content.onAppear {
      analyticsUseCase.track(.screenView(screen))
    }
  }
}
