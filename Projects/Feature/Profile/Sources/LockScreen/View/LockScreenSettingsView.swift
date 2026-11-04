//
//  LockScreenSettingsView.swift
//  Profile
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: LockScreenSettingsFeature.self)
public struct LockScreenSettingsView: View {
  @Environment(\.scenePhase) private var scenePhase
  public let store: StoreOf<LockScreenSettingsFeature>

  public init(store: StoreOf<LockScreenSettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: "잠금화면")
        .onBack { send(.backTapped) }

      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          activityStatus
          if !store.activities.isEmpty {
            activeActivities
            FCButton("모두 끄기") { send(.stopAllTapped) }
              .style(.secondary)
              .size(.medium)
              .disabled(store.isStopping)
          }
          Text("축제 라이브 보드에서 라이브 활동을 켜면 잠금화면에서 진행 상황을 볼 수 있어요.")
            .festiCoreFont(.baseBodyRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          FCButton("시스템 설정 열기") { send(.openSystemSettingsTapped) }
            .style(.secondary)
            .size(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FestiCoreSpacing.paddingP20)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .onAppear { send(.onAppear) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { send(.onAppear) }
    }
  }
}

private extension LockScreenSettingsView {
  var activeActivities: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      ForEach(store.activities, id: \.id) { activity in
        Text("축제 ID: \(activity.festivalID)")
          .festiCoreFont(.baseBodyRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      }
    }
  }

  @ViewBuilder
  var activityStatus: some View {
    if store.isLoading {
      FCSkeletonView(.round())
        .frame(width: 180, height: 24)
        .accessibilityLabel("라이브 활동을 불러오는 중")
    } else {
      Text(store.activityCount == 0
        ? "잠금화면에 표시 중인 라이브 활동이 없어요"
        : "잠금화면에 표시 중인 라이브 활동 \(store.activityCount)개")
        .festiCoreFont(.baseTitle3Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
    }
  }
}
