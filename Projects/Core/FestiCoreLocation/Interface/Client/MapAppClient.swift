//
//  MapAppClient.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/12/26.
//

import Dependencies

/// 가는 길에서 여는 외부 지도 앱. 원시 값은 설치 확인에 쓰는 URL 스킴이며 앱 Info.plist의 `LSApplicationQueriesSchemes`에 등록한다.
public enum MapApp: String, CaseIterable, Sendable {
  case naver = "nmap"
  case kakao = "kakaomap"
}

/// 외부 지도 앱 설치 여부를 확인하는 경계. `UIApplication.canOpenURL`은 라이브 구현에만 둔다.
public protocol MapAppClient: Sendable {
  /// 지도 앱이 설치돼 있으면 true다.
  func isInstalled(_ app: MapApp) async -> Bool
}

public enum MapAppClientDependency: TestDependencyKey {
  public static var testValue: any MapAppClient {
    return MockMapAppClient()
  }
  /// 프리뷰에서는 지도 앱이 모두 있다고 본다.
  public static var previewValue: any MapAppClient {
    return MockMapAppClient { _ in true }
  }
}

public extension DependencyValues {
  var mapAppClient: any MapAppClient {
    get { self[MapAppClientDependency.self] }
    set { self[MapAppClientDependency.self] = newValue }
  }
}
