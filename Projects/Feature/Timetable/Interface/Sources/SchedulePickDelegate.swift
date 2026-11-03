//
//  SchedulePickDelegate.swift
//  TimetableInterface
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture

/// 준비 안내 1단계(내 일정 고르기)가 부모에게 알리는 결과
@CasePathable
public enum SchedulePickDelegate: Equatable, Sendable {
  /// 고른 공연을 서버 내 일정에 저장했다. 다음 단계로 넘어간다.
  case saved(festivalID: String, setIDs: Set<String>)
  /// 이 단계를 저장하지 않고 넘긴다.
  case skipped
  /// 준비 안내 전체를 나중에 한다.
  case later
}
