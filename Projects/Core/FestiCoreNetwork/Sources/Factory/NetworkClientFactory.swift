//
//  NetworkClientFactory.swift
//  FestiCoreNetwork
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

import FestiCoreNetworkInterface

/// `FestiCoreNetworkClient` 조립 진입점. 호출부는 이 팩토리만 알면 된다.
public enum NetworkClientFactory {
  public static func webSocket() -> any FestiCoreWebSocketClient {
    return URLSessionWebSocketClient(
      configuration: SessionFactory.webSocketConfiguration,
      monitor: WebSocketMonitor()
    )
  }

  /// Info.plist 의 `FestiCoreAPIHost`(호스트만 담긴 값)로 조립한 앱 서버 baseURL.
  /// 값이 없으면 nil 이고, 그 클라이언트의 요청은 `.request(.invalidURL)` 로 즉시 실패한다.
  public static var bundleBaseURL: URL? {
    guard let host = Bundle.main.object(forInfoDictionaryKey: "FestiCoreAPIHost") as? String,
          !host.isEmpty
    else {
      return nil
    }
    return URL(string: "https://\(host)")
  }

  /// 인증 없는 기본 클라이언트.
  public static func plain(baseURL: URL? = NetworkClientFactory.bundleBaseURL) -> any FestiCoreNetworkClient {
    NetworkClient(
      session: SessionFactory.plain(),
      baseURL: baseURL
    )
  }

  /// 단일 클라이언트 — 요청의 `authorization` 정책에 따라 요청 시점에 인증 부착을 판단한다.
  /// (`.automatic`: 로그인 상태면 토큰 부착, `.none`: 인증 파이프라인 우회)
  ///
  /// 반환된 `credentials` 로 로그인 / 로그아웃 시점의 토큰 교체를 세션에 반영해야 한다.
  public static func unified(
    store: CredentialStore,
    refresher: TokenRefreshing,
    baseURL: URL? = NetworkClientFactory.bundleBaseURL
  ) -> (client: any FestiCoreNetworkClient, credentials: any CredentialUpdating) {
    let (authorizing, credentials) = SessionFactory.authorization(
      store: store,
      refresher: refresher
    )
    return (
      NetworkClient(
        session: SessionFactory.plain(),
        baseURL: baseURL,
        authorizing: authorizing
      ),
      credentials
    )
  }
}
