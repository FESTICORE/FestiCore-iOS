//
//  AppCoordinator+Effects.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import Foundation

// MARK: - 홈 상태 접근

extension AppCoordinator.State {
  /// 홈일 때만 홈 상태를 고치고 다시 저장한다. 홈이 아니면 아무것도 하지 않는다.
  mutating func withHome(
    _ body: (inout MainTabCoordinator.State) -> Effect<AppCoordinator.Action>
  ) -> Effect<AppCoordinator.Action> {
    guard case var .home(home) = self else { return .none }
    defer { self = .home(home) }
    return body(&home)
  }
}
