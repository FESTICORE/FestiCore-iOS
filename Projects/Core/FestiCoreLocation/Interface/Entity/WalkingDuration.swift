//
//  WalkingDuration.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

import Foundation

/// Apple 지도가 계산한 도보 소요 시간
public struct WalkingDuration: Equatable, Sendable {
  public let seconds: TimeInterval

  public init(seconds: TimeInterval) {
    self.seconds = seconds
  }

  /// 화면에 보일 분. 막차를 놓치지 않도록 남는 초는 1분으로 올리고 최소 1분이다.
  /// 음수·무한대나 정수로 나타낼 수 없는 큰 값이면 nil이다.
  public var minutes: Int? {
    guard seconds.isFinite, seconds >= 0,
          let minutes = Int(exactly: (seconds / 60).rounded(.up)) else { return nil }
    return max(
      1,
      minutes
    )
  }
}
