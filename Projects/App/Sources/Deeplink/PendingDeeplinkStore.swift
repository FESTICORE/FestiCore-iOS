//
//  PendingDeeplinkStore.swift
//  FestiCore
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreStorageInterface
import FestiCoreUtility
import Sharing

/// 홈이 준비되기 전에 들어온 딥링크 하나를 보관한다. 새 딥링크가 오면 이전 값을 덮어쓴다.
struct PendingDeeplinkStore: Sendable {
  @Shared(.pendingDeeplink) private var encoded: String?

  func save(_ deeplink: FestiCoreDeeplink) {
    $encoded.withLock { $0 = deeplink.encoded }
  }

  func consume() -> FestiCoreDeeplink? {
    return $encoded.withLock { value in
      defer { value = nil }
      return value.flatMap { FestiCoreDeeplinkParser.parse(urlString: $0) }
    }
  }
}
