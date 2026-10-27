//
//  FestiCoreLottieSource.swift
//  FestiCoreAnimation
//
//  Created by FestiCore on 10/27/26.
//

import Foundation

public enum FestiCoreLottieFormat: Sendable {
  case json
  case dotLottie
}

/// 호출자가 소유한 번들 에셋 또는 HTTPS 원격 애니메이션입니다.
public enum FestiCoreLottieSource {
  case asset(name: String, bundle: Bundle)
  case remote(url: URL, format: FestiCoreLottieFormat)

  var isValidRemoteSource: Bool {
    guard case let .remote(url, _) = self else { return false }
    return url.scheme?.lowercased() == "https" && url.host != nil
  }
}
