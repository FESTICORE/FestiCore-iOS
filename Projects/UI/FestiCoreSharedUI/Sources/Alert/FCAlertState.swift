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
  public let style: FCAlertStyle

  public init(
    title: String,
    message: String = "",
    confirmTitle: String = "확인",
    cancelTitle: String = "취소",
    style: FCAlertStyle = .confirmation
  ) {
    self.title = title
    self.message = message
    self.confirmTitle = confirmTitle
    self.cancelTitle = cancelTitle
    self.style = style
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.title == rhs.title
      && lhs.message == rhs.message
      && lhs.confirmTitle == rhs.confirmTitle
      && lhs.cancelTitle == rhs.cancelTitle
      && lhs.style == rhs.style
  }
}

/// 다이얼로그 모양. 지금은 DesignKit `FCDialog`의 확인·취소 두 버튼 모양 하나뿐이다.
public enum FCAlertStyle: Equatable {
  case confirmation
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
      cancelTitle: cancelTitle,
      style: .confirmation
    )
  }

  /// 회원 탈퇴 확인
  static func withdraw() -> FCAlertState<FCAlertAction> {
    .alert(
      title: "회원 탈퇴",
      message: "계정과 로그인 정보가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.",
      confirmTitle: "탈퇴"
    )
  }

  /// 약관·개인정보 문서 주소가 없을 때 안내
  static func legalLinkUnavailable() -> FCAlertState<FCAlertAction> {
    .alert(
      title: "문서를 열 수 없어요",
      message: "잠시 후 다시 시도해 주세요.",
      confirmTitle: "확인"
    )
  }

  /// 받은 팩 삭제 확인
  static func deletePack(name: String) -> FCAlertState<FCAlertAction> {
    .alert(
      title: "\(name) 팩을 삭제할까요?",
      message: "시간표·가는 길·준비물을 오프라인으로 볼 수 없게 돼요. 내 일정과 체크한 준비물은 남아 있어요.",
      confirmTitle: "삭제"
    )
  }

  /// 안내 숨김 확인
  static func hideGuide() -> FCAlertState<FCAlertAction> {
    .alert(
      title: "이 안내를 숨길까요?",
      message: "이번 페스티벌 동안 라이브 보드에서 이 안내를 숨깁니다. 깃발 탭에서는 언제든 깃발을 찾을 수 있어요.",
      confirmTitle: "숨기기"
    )
  }

  /// 로그아웃 확인
  static func logout() -> FCAlertState<FCAlertAction> {
    .alert(
      title: "로그아웃",
      message: "이 기기에서 로그아웃하시겠습니까?",
      confirmTitle: "로그아웃"
    )
  }
}
