//
//  FlagCoordinatorView.swift
//  FestiCore
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

/// 깃발 탭. 디렉토리와 상세 모두 자체 상단 바를 쓰므로 시스템 내비게이션 바를 숨긴다.
struct FlagCoordinatorView: View {
  @Bindable var store: StoreOf<FlagCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(
      \.routes,
      action: \.router
    )) { screen in
      switch screen.case {
      case let .directory(directoryStore):
        FestivalFlagView(store: directoryStore)
          .toolbar(
            .hidden,
            for: .navigationBar
          )

      case let .detail(detailStore):
        FestivalFlagDetailView(store: detailStore)
          .toolbar(
            .hidden,
            for: .navigationBar
          )
          .swipeBackButtonHidden()
      }
    }
  }
}
