//
//  WalkingDurationTests.swift
//  FestiCoreLocationTests
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreLocationInterface
import Foundation
import Testing

@Suite("도보 소요 분")
struct WalkingDurationTests {
  @Test(
    "남는 초는 1분으로 올리고 최소 1분으로 보인다",
    arguments: [
      (0.0, 1),
      (1.0, 1),
      (59.0, 1),
      (60.0, 1),
      (61.0, 2),
      (599.0, 10),
      (600.0, 10),
      (601.0, 11),
    ]
  )
  func roundsUpToWholeMinutes(
    seconds: TimeInterval,
    minutes: Int
  ) {
    #expect(WalkingDuration(seconds: seconds).minutes == minutes)
  }

  @Test(
    "잘못된 소요 시간은 분으로 바꾸지 않는다",
    arguments: [
      -1.0,
      .infinity,
      .nan,
      .greatestFiniteMagnitude,
    ]
  )
  func rejectsInvalidSeconds(seconds: TimeInterval) {
    #expect(WalkingDuration(seconds: seconds).minutes == nil)
  }
}
