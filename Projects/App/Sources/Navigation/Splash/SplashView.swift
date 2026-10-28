//
//  SplashView.swift
//  FestiCore
//
//  Created by FestiCore on 10/28/26.
//

import ComposableArchitecture
import FestiCoreAnimation
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: SplashFeature.self)
struct SplashView: View {
  @Bindable var store: StoreOf<SplashFeature>

  var body: some View {
    ZStack {
      Color.staticInk
        .ignoresSafeArea()

      GeometryReader { geometry in
        let isWide = geometry.size.width > geometry.size.height * (FestiCoreAnimationAsset.splash.canvasAspectRatio ?? 1)

        FestiCoreLottieView(.splash)
          .duration(2)
          .contentMode(isWide ? .scaleAspectFill : .scaleAspectFit)
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
      }
      .ignoresSafeArea()
    }
    .statusBarHidden()
    .onAppear { send(.onAppear) }
    .accessibilityIdentifier("splash_root")
  }
}

#Preview {
  SplashView(
    store: Store(initialState: SplashFeature.State()) {
      SplashFeature()
    }
  )
}
