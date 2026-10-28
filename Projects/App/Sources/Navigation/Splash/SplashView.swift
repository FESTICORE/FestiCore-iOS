//
//  SplashView.swift
//  FestiCore
//
//  Created by FestiCore on 10/28/26.
//

import ComposableArchitecture
import FestiCoreAnimation
import SwiftUI

@ViewAction(for: SplashFeature.self)
struct SplashView: View {
  @Bindable var store: StoreOf<SplashFeature>

  // Splash 원본은 밝기 모드와 관계없이 #111113 배경을 사용합니다.
  private let background = Color(red: 17.0 / 255, green: 17.0 / 255, blue: 19.0 / 255)

  var body: some View {
    ZStack {
      background
        .ignoresSafeArea()

      FestiCoreLottieView(.splash)
        .duration(3)
        .aspectRatio(FestiCoreAnimationAsset.splash.canvasAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    .statusBarHidden()
    .onAppear { send(.onAppear) }
    .onDisappear { send(.onDisappear) }
    .accessibilityIdentifier("splash_root")
  }
}
