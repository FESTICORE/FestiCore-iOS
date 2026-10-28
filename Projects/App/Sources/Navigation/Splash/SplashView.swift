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

      FestiCoreLottieView(.splash)
        .duration(2)
        .aspectRatio(FestiCoreAnimationAsset.splash.canvasAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
