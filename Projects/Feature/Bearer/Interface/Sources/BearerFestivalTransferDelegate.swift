//
//  BearerFestivalTransferDelegate.swift
//  BearerInterface
//
//  Created by FestiCore on 11/26/26.
//

import ComposableArchitecture

/// 깃발 축제 이동(S10 깃발 상세 메뉴)이 부모에게 알리는 결과
@CasePathable
public enum BearerFestivalTransferDelegate: Equatable, Sendable {
  /// 뒤로. 부모가 깃발 상세로 돌아간다.
  case backRequested
  /// 깃발을 옮겼다. 부모가 깃발 상세로 돌아가 새 페스티벌 값으로 다시 불러온다.
  case transferred(
    flagID: String,
    festivalID: String
  )
}
