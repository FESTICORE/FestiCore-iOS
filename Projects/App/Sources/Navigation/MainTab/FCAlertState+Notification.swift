//
//  FCAlertState+Notification.swift
//  FestiCore
//
//  Created by FestiCore on 11/15/26.
//

import FestiCoreSharedUI

/// 홈에서 쓰는 알림 권한 안내 문구
extension FCAlertState where Action == FCAlertAction {
  /// 알림 권한을 거부했을 때 설정으로 안내
  static func notificationSettings() -> FCAlertState<FCAlertAction> {
    return .alert(
      title: "알림이 꺼져 있어요",
      message: "알림을 받으려면 설정에서 알림을 허용해 주세요. 알림 없이도 앱을 사용할 수 있어요.",
      confirmTitle: "설정 열기",
      cancelTitle: "나중에"
    )
  }
}
