//
//  LocationAuthorization.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

/// 앱의 위치 권한 상태. 앱은 사용 중일 때만 위치를 쓴다.
public enum LocationAuthorization: Equatable, Sendable {
  /// 아직 묻지 않았다. 필요한 순간에 한 번 요청할 수 있다.
  case notDetermined
  /// 사용자가 거부했다. 설정 앱에서만 바꿀 수 있다.
  case denied
  /// 기기 관리·자녀 보호 설정으로 막혀 있다.
  case restricted
  /// 사용 중 또는 항상 허용
  case authorized
}
