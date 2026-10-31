//
//  FestiCoreAnimations.swift
//  FestiCoreAnimation
//
//  Created by FestiCore on 10/31/26.
//

import SwiftUI

/// 화면 전환에 쓰는 공용 애니메이션 값. Attendance `AppAnimations`와 같은 값을 쓴다.
public enum FestiCoreAnimations {
  /// 확인 다이얼로그처럼 가운데에 뜨는 모달의 등장·닫힘.
  public static let modalTransition = Animation.spring(
    response: 0.42,
    dampingFraction: 0.88
  )
}

public extension Animation {
  /// 모달 등장·닫힘 애니메이션.
  static var fcModal: Animation {
    FestiCoreAnimations.modalTransition
  }
}
