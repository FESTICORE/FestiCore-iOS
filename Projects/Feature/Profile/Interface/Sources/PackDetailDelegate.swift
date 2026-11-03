//
//  PackDetailDelegate.swift
//  ProfileInterface
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture

@CasePathable
public enum PackDetailDelegate: Equatable, Sendable {
  case backRequested
  /// 팩을 새로 받았거나 확인해 마이 화면 목록을 다시 읽어야 한다.
  case packChanged
  /// 팩을 지워 상세 화면을 닫아야 한다.
  case packDeleted
}
