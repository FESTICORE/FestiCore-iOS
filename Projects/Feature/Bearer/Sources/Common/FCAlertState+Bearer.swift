//
//  FCAlertState+Bearer.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreSharedUI

/// 기수 화면에서만 쓰는 확인 팝업 문구
extension FCAlertState where Action == FCAlertAction {
  /// 공동 기수 초대 코드 안내
  static func coBearerInvite(code: String) -> FCAlertState<FCAlertAction> {
    .alert(
      title: "공동 기수 초대 코드",
      message: "\(code)\n24시간 안에 함께할 기수가 기수 인증 코드에 입력하면 돼요.",
      confirmTitle: "확인",
      cancelTitle: "닫기"
    )
  }

  /// 공동 기수 초대 실패
  static func coBearerInviteFailed(message: String) -> FCAlertState<FCAlertAction> {
    .alert(title: "초대하지 못했어요", message: message, confirmTitle: "확인", cancelTitle: "닫기")
  }
}
