//
//  LockScreenSettingsView.swift
//  Profile
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

@ViewAction(for: LockScreenSettingsFeature.self)
public struct LockScreenSettingsView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Bindable public var store: StoreOf<LockScreenSettingsFeature>

  public init(store: StoreOf<LockScreenSettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: "잠금화면")
        .onBack { send(.backTapped) }

      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          autoStartGroup
          if store.hasSession {
            pinnedFlagGroup
          }
          activityStatus
          if !store.activities.isEmpty {
            activeActivities()
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
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP20
        )
        .padding(
          .top,
          FestiCoreSpacing.paddingP20
        )
      }
      .fcScrollBottomInset()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .onAppear { send(.onAppear) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { send(.onAppear) }
    }
    .fcModal(
      $store.scope(
        state: \.destination?.flagPicker,
        action: \.destination.flagPicker
      ),
      height: .fraction(0.6)
    ) { pickerStore in
      PinnedFlagPickerView(store: pickerStore)
    }
    .overlay {
      Color.clear
        .fcAlert(
          $store.scope(
            state: \.destination?.alert,
            action: \.destination.alert
          ),
          dismissesOnDimTap: true,
          textAlignment: .center
        )
    }
  }
}

private extension LockScreenSettingsView {
  /// Figma S13-C Live Activity 그룹: 제목 Footnote/Bold, 카드 r16, 각주 Footnote/Regular
  var autoStartGroup: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text("Live Activity")
        .festiCoreFont(.baseFootnoteBold)
        .festiCoreLineBox(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP4
        )
      FCListRow(
        "당일 자동 시작",
        isOn: autoStartBinding
      )
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
      Text("페스티벌 당일 라이브 보드를 처음 열면 잠금화면에 지금 무대와 다음 일정이 떠요. 끄면 보드 오른쪽 위 버튼으로 직접 켤 수 있어요.")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .fixedSize(
          horizontal: false,
          vertical: true
        )
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP4
        )
    }
  }

  /// Figma S13-C 깃발 그룹: Live Activity 그룹과 같은 제목·카드·각주 스타일
  var pinnedFlagGroup: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text("깃발")
        .festiCoreFont(.baseFootnoteBold)
        .festiCoreLineBox(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP4
        )
      FCListRow("잠금화면에 보일 깃발") { send(.pinnedFlagTapped) }
        .value(pinnedFlagValue)
        .background(
          FestiCoreSemanticColor.backgroundElevated.color,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        )
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
        .disabled(store.isSavingPinnedFlag)
      Text("팔로우한 깃발 중 1개만 보여요. 고르지 않으면 가장 최근에 팔로우한 깃발이 보여요.")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .fixedSize(
          horizontal: false,
          vertical: true
        )
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP4
        )
    }
  }

  /// 줄 오른쪽 현재 값. 읽는 중이면 비워 둔다.
  var pinnedFlagValue: String? {
    if store.isSavingPinnedFlag { return "저장하는 중" }
    switch store.pinnedFlag {
    case .loading: return nil
    case .failed: return "불러오지 못했어요"
    case .loaded(nil): return "고르지 않음"
    case let .loaded(flag?): return flag.name
    }
  }

  var autoStartBinding: Binding<Bool> {
    return Binding(
      get: { store.isAutoStartOn },
      set: { send(.autoStartToggled($0)) }
    )
  }

  @ViewBuilder
  func activeActivities() -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP12
    ) {
      ForEach(
        store.activities,
        id: \.id
      ) { activity in
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
