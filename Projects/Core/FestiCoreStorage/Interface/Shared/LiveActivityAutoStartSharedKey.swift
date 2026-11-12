//
//  LiveActivityAutoStartSharedKey.swift
//  FestiCoreStorageInterface
//
//  Created by FestiCore on 11/12/26.
//

import Foundation

import Sharing

public extension SharedReaderKey where Self == PersistentSharedKey<Bool>.Default {
  /// 마이 > 설정 > 잠금화면(Figma S13-C)의 '당일 자동 시작'. 켜져 있으면 페스티벌 당일 라이브 보드를 처음 열 때
  /// 잠금화면 라이브 활동을 자동으로 시작한다. 지금까지 자동 시작이 늘 켜져 있었으므로 기본은 켬이다.
  static var liveActivityAutoStart: Self {
    return Self[
      .persistent(
        "FestiCore.liveActivity.autoStart",
        encode: { try JSONEncoder().encode($0) },
        decode: { data in
          return try JSONDecoder().decode(
            Bool.self,
            from: data
          )
        }
      ),
      default: true
    ]
  }
}
