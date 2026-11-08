//
//  AppearanceModeSharedKey.swift
//  FestiCoreStorageInterface
//
//  Created by FestiCore on 11/9/26.
//

import Foundation

import Sharing

public extension SharedReaderKey where Self == PersistentSharedKey<String>.Default {
  /// 마이 > 화면 모드(Figma S13-J)의 원시 값(`system`·`light`·`dark`). 지금까지 다크 고정이라 기본은 `dark`다.
  /// 이전 앱이 UserDefaults(appStorage `FestiCoreAppearanceMode`)에 둔 선택은 처음 읽을 때 옮긴다.
  static var appearanceMode: Self {
    return appearanceMode(legacyValue: {
      return UserDefaults.standard.string(forKey: AppearanceModeLegacy.userDefaultsKey)
    })
  }

  /// 이전 값을 읽는 곳을 바꿔 끼울 수 있는 키. 테스트에서 이전 경로를 확인한다.
  static func appearanceMode(legacyValue: @escaping @Sendable () -> String?) -> Self {
    return Self[
      .persistent(
        "FestiCore.appearanceMode",
        encode: { try JSONEncoder().encode($0) },
        decode: { data in
          return try JSONDecoder().decode(
            String.self,
            from: data
          )
        },
        legacyData: {
          return try legacyValue().map { try JSONEncoder().encode($0) }
        }
      ),
      default: "dark"
    ]
  }
}

/// 화면 모드를 UserDefaults(appStorage)에 두던 이전 키
public enum AppearanceModeLegacy {
  public static let userDefaultsKey = "FestiCoreAppearanceMode"
}
