//
//  SecureStorageKey.swift
//  FestiCoreStorageInterface
//
//  Created by FestiCore on 10/22/26.
//

public struct SecureStorageKey: Hashable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public extension SecureStorageKey {
  // 네트워크 모듈과 앱이 공유하는 세션 키입니다.
  static let accessToken = SecureStorageKey("ACCESS_TOKEN")
  static let refreshToken = SecureStorageKey("REFRESH_TOKEN")
  static let deviceID = SecureStorageKey("DEVICE_ID")
  static let deviceAccessToken = SecureStorageKey("DEVICE_ACCESS_TOKEN")

  // 로그아웃 시 앱 설치 단위의 기기 식별 정보는 유지합니다.
  static let all: [SecureStorageKey] = [.accessToken, .refreshToken]
}
