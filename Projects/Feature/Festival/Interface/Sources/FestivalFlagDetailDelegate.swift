//
//  FestivalFlagDetailDelegate.swift
//  FestivalInterface
//
//  Created by FestiCore on 11/7/26.
//

import ComposableArchitecture

/// 깃발 상세 화면이 부모에게 알리는 결과.
@CasePathable
public enum FestivalFlagDetailDelegate: Equatable, Sendable {
  /// 상단 뒤로 가기. 부모가 상세 경로를 닫는다.
  case backRequested
  /// 비로그인 팔로우. 부모가 로그인 시트를 띄운다.
  case loginRequested
  /// 약관 동의가 필요한 팔로우·신고·대표 깃발 지정. 부모가 약관 화면을 띄운다.
  case termsAcceptanceRequested
  /// 비로그인 신고·대표 깃발 지정. 부모가 일반 로그인 시트를 띄운다.
  case reportLoginRequested
  /// 상세에서 팔로우를 바꿨다. 부모가 깃발 목록 카드에 같은 값을 반영한다.
  case followChanged(
    flagID: String,
    isFollowing: Bool,
    followerCount: Int
  )
}
