//
//  FestivalDelegate.swift
//  FestivalInterface
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture

@CasePathable
public enum FestivalDelegate: Equatable, Sendable {
  case bookmarkRequested(String)
  case loginRequested
  /// 라이브 보드 상단 기수 버튼. 부모가 기수 보드를 연다.
  case bearerBoardRequested(festivalID: String, flagID: String, userID: String?)
}
