//
//  FestiCoreAnimationAsset.swift
//  FestiCoreAnimation
//
//  Created by FestiCore on 10/28/26.
//

import Foundation
import Lottie

/// 이 모듈의 Resources에 포함된 Lottie 파일 이름입니다.
public enum FestiCoreAnimationAsset: String, Sendable {
  case splash = "Splash"

  /// Lottie 원본 캔버스 크기입니다.
  public var canvasSize: CGSize? {
    guard let animation = LottieAnimation.named(rawValue, bundle: Bundle(for: FestiCoreAnimationBundleMarker.self)),
          animation.bounds.width > 0,
          animation.bounds.height > 0 else { return nil }

    return animation.bounds.size
  }

  public var canvasAspectRatio: CGFloat? {
    guard let canvasSize else { return nil }
    return canvasSize.width / canvasSize.height
  }
}

final class FestiCoreAnimationBundleMarker {}
