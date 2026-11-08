//
//  AppearanceMode.swift
//  Profile
//
//  Created by FestiCore on 11/8/26.
//

import SwiftUI

/// 화면 모드(Figma S13-J). 앱 루트가 `preferredColorScheme`으로 적용한다.
public enum AppearanceMode: String, CaseIterable, Equatable, Sendable {
  case system
  case light
  case dark

  /// 저장된 원시 값(`appearanceMode` 키)에서 만든다. 알 수 없는 값은 지금까지처럼 다크로 본다.
  public init(storedValue: String) {
    self = AppearanceMode(rawValue: storedValue) ?? .dark
  }

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
