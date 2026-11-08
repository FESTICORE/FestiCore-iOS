//
//  PendingDeeplinkSharedKey.swift
//  FestiCoreStorageInterface
//
//  Created by FestiCore on 11/8/26.
//

import Foundation

import Sharing

public extension SharedReaderKey where Self == PersistentSharedKey<String?>.Default {
  /// 홈 화면 준비 전에 도착한 최신 딥링크(URL 문자열). 소비한 nil도 저장해 이전 값을 다시 읽지 않는다.
  static var pendingDeeplink: Self {
    return Self[
      .persistent(
        "FestiCore.pendingDeeplink",
        encode: { try JSONEncoder().encode($0) },
        decode: { data in
          return try JSONDecoder().decode(
            String?.self,
            from: data
          )
        }
      ),
      default: nil
    ]
  }
}
