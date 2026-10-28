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
        if let canvas = FestiCoreAnimationAsset.splash.canvasSize, geometry.size.width > 0 {
          // 원본 로고와 문구가 들어 있는 중앙 영역을 Duo 가로 화면에서도 유지한다.
          let visibleCanvasHeight = min(
            canvas.height,
            max(450, canvas.width * geometry.size.height / geometry.size.width)
          )
          let scale = geometry.size.height / visibleCanvasHeight

          FestiCoreLottieView(.splash)
            .duration(2)
            .playOnce()
            .frame(width: canvas.width * scale, height: canvas.height * scale)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        } else {
          FestiCoreLottieView(.splash)
            .duration(2)
            .playOnce()
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
      }
      .ignoresSafeArea()
      .clipped()
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
