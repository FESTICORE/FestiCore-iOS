//
//  AppDeeplinkBridge.swift
//  FestiCore
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreUtility
import Foundation
import OSLog

/// 위젯 URL과 푸시 탭을 딥링크로 바꿔 대기 저장소에 넣고, 홈이 꺼내 가도록 알린다.
enum AppDeeplinkBridge {
  private static let logger = Logger(
    subsystem: "io.festiCore.co",
    category: "Deeplink"
  )

  private static var pendingStore: PendingDeeplinkStore {
    return PendingDeeplinkStore()
  }

  /// 알림 탭: userInfo의 `deeplink`(없으면 `route`·ID)를 읽는다.
  static func handlePushPayload(_ userInfo: [AnyHashable: Any]) {
    guard let deeplink = FestiCoreDeeplinkParser.parse(pushPayload: userInfo) else {
      logger.debug("처리할 딥링크가 없는 푸시")
      return
    }
    broadcast(deeplink)
  }

  /// `festicore://` URL로 앱이 열렸을 때. 딥링크가 아니면 거짓을 돌려 OAuth 처리로 넘긴다.
  @discardableResult
  static func handleURL(_ url: URL) -> Bool {
    guard let deeplink = FestiCoreDeeplinkParser.parse(url: url) else { return false }
    broadcast(deeplink)
    return true
  }

  static func broadcast(_ deeplink: FestiCoreDeeplink) {
    pendingStore.save(deeplink)
    NotificationCenter.default.post(
      name: .festiCoreDeeplink,
      object: nil
    )
    logger.debug("딥링크 대기: \(deeplink.encoded, privacy: .public)")
  }

  static func consumePending() -> FestiCoreDeeplink? {
    return pendingStore.consume()
  }
}
