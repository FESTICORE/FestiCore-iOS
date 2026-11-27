//
//  AnalyticsCollectionSharedKey.swift
//  FestiCoreStorageInterface
//
//  Created by FestiCore on 11/28/26.
//

import Foundation
import Sharing

public extension SharedReaderKey where Self == PersistentSharedKey<Bool>.Default {
  /// 사용자가 선택하기 전에는 분석과 진단을 수집하지 않는다.
  static var analyticsCollectionEnabled: Self {
    return Self[
      .persistent(
        "FestiCore.analytics.collectionEnabled",
        encode: { try JSONEncoder().encode($0) },
        decode: { try JSONDecoder().decode(
          Bool.self,
          from: $0
        ) }
      ),
      default: false
    ]
  }
}
