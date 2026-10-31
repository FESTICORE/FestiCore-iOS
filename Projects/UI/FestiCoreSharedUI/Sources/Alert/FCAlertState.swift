//
//  FCAlertState.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// Feature 상태에 `@Presents`로 들고 있는 확인 다이얼로그 내용
@ObservableState
public struct FCAlertState<Action>: Equatable {
  /// 표시마다 새로 만드는 ID. 같은 내용을 다시 띄워도 등장 애니메이션을 다시 재생한다. 내용 비교에는 쓰지 않는다.
  public let presentationID = UUID()
  public let title: String
  public let message: String
  public let confirmTitle: String
  public let cancelTitle: String

  public init(
    title: String,
    message: String = "",
    confirmTitle: String = "확인",
    cancelTitle: String = "취소"
  ) {
    self.title = title
    self.message = message
    self.confirmTitle = confirmTitle
    self.cancelTitle = cancelTitle
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.title == rhs.title
      && lhs.message == rhs.message
      && lhs.confirmTitle == rhs.confirmTitle
      && lhs.cancelTitle == rhs.cancelTitle
  }
}

@CasePathable
public enum FCAlertAction: Equatable {
  case confirmTapped
  case cancelTapped
}

@Reducer
public struct FCConfirmAlert {
  public init() {}

  public var body: some Reducer<FCAlertState<FCAlertAction>, FCAlertAction> {
    EmptyReducer()
  }
}

public extension FCAlertState where Action == FCAlertAction {
  static func alert(
    title: String,
    message: String = "",
    confirmTitle: String = "확인",
    cancelTitle: String = "취소"
  ) -> FCAlertState<FCAlertAction> {
    FCAlertState(
      title: title,
      message: message,
      confirmTitle: confirmTitle,
      cancelTitle: cancelTitle
    )
  }

  /// 안내 숨김 확인
  static func hideGuide() -> FCAlertState<FCAlertAction> {
    .alert(
      title: "이 안내를 숨길까요?",
      message: "마이 > 설정에서 다시 켤 수 있어요.",
      confirmTitle: "숨기기"
    )
  }
}
