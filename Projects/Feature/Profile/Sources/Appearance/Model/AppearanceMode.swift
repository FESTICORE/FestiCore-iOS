//
//  AppearanceMode.swift
//  Profile
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import SwiftUI

/// 화면 모드(Figma S13-J). 앱 루트가 `preferredColorScheme`으로 적용한다.
public enum AppearanceMode: String, CaseIterable, Equatable, Sendable {
  case system
  case light
  case dark

  /// 화면 모드 화면의 줄 이름
  public var title: String {
    switch self {
    case .system: return "시스템 설정과 같게"
    case .light: return "라이트"
    case .dark: return "다크"
    }
  }

  /// 마이 설정의 '화면 모드' 줄에 보이는 값
  public var summary: String {
    switch self {
    case .system: return "시스템 설정"
    case .light: return "라이트"
    case .dark: return "다크"
    }
  }

  /// 시스템 설정과 같게는 nil이라 기기 설정을 따른다.
  public var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}

public extension SharedKey where Self == AppStorageKey<AppearanceMode>.Default {
  /// 고른 화면 모드. 지금까지 앱이 다크로 고정돼 있었으므로 기본값은 다크다.
  /// 키에 `.`이 있으면 UserDefaults 값 관찰(KVO)을 쓰지 못해 붙여 쓴다.
  static var appearanceMode: Self {
    return Self[
      .appStorage("FestiCoreAppearanceMode"),
      default: .dark
    ]
  }
}
