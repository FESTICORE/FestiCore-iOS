//
//  NotificationSettingsView.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestivalDomainInterface
import SwiftUI

/// Figma S13 A 알림 · B 기기 알림 꺼짐
@ViewAction(for: NotificationSettingsFeature.self)
public struct NotificationSettingsView: View {
  @Bindable public var store: StoreOf<NotificationSettingsFeature>
  @Environment(\.scenePhase) private var scenePhase

  public init(store: StoreOf<NotificationSettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: "알림")
        .onBack { send(.backTapped) }
      content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(.hidden, for: .navigationBar)
    .onAppear { send(.onAppear) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { send(.onAppear) }
    }
  }
}

extension NotificationSettingsView {
  @ViewBuilder
  private var content: some View {
    switch store.load {
    case .loading:
      VStack(spacing: FestiCoreSpacing.paddingP24) {
        ForEach(0 ..< 3, id: \.self) { _ in
          FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
            .frame(height: 112)
        }
      }
      .padding(FestiCoreSpacing.paddingP16)
      .frame(maxHeight: .infinity, alignment: .top)
    case .failed:
      VStack(spacing: FestiCoreSpacing.paddingP12) {
        Text("알림 설정을 불러오지 못했어요")
          .festiCoreFont(.baseBodyRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        FCButton("다시 시도") { send(.retryTapped) }
          .style(.secondary)
          .size(.medium)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .loaded:
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          if store.isDeviceNotificationOff {
            FCBanner("기기 설정에서 알림이 꺼져 있어요 · 설정 열기") { send(.openSystemSettingsTapped) }
          }
          group(
            "깃발 · 크루",
            rows: [("팔로우한 깃발 이동", .flagStatus), ("크루원 상태", .crewStatus), ("크루 모여! 요청", .crewGather)],
            footnote: "크루원 상태는 소리 없이 와요. 모여! 요청만 소리로 알려 드려요."
          )
          group(
            "공연 · 귀가",
            rows: [("공연 10분 전", .setReminders), ("귀가 알림", .homecoming)],
            footnote: "귀가 알림은 공연이 끝나기 1시간 전에 막차와 셔틀 시간을 알려 드려요."
          )
          group(
            "팩",
            rows: [("팩 업데이트", .packUpdates)],
            footnote: "시간표가 바뀌면 받은 팩을 새로 받으라고 알려 드려요."
          )
          if let message = store.message {
            Text(message)
              .festiCoreFont(.baseFootnoteRegular)
              .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
              .accessibilityAddTraits(.updatesFrequently)
          }
        }
        // Figma S13-A Contents: 위 16·아래 24
        .padding(.horizontal, FestiCoreSpacing.paddingP16)
        .padding(
          .top,
          FestiCoreSpacing.paddingP16
        )
      }
      .scrollIndicators(.hidden)
      .fcScrollBottomInset()
    }
  }

  private func group(
    _ title: String,
    rows: [(String, NotificationSettingsFeature.Kind)],
    footnote: String
  ) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      // Figma 그룹 제목: Pretendard Bold 13, 줄 높이 18
      Text(title)
        .festiCoreFont(.baseFootnoteBold)
        .festiCoreLineBox(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .padding(.horizontal, FestiCoreSpacing.paddingP4)
      VStack(spacing: .zero) {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
          if index > 0 {
            FestiCoreSemanticColor.lineNormal.color
              .frame(height: 1)
              // Figma S13-A Divider: 좌우 16 안쪽(345)
              .padding(
                .horizontal,
                FestiCoreSpacing.paddingP16
              )
          }
          FCListRow(row.0, isOn: toggleBinding(row.1))
            .disabled(store.isDeviceNotificationOff)
        }
      }
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
      Text(footnote)
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, FestiCoreSpacing.paddingP4)
    }
  }

  /// 기기 알림이 꺼져 있으면 모두 꺼진 채로 보인다.
  private func toggleBinding(_ kind: NotificationSettingsFeature.Kind) -> Binding<Bool> {
    Binding(
      get: { !store.isDeviceNotificationOff && (store.settings?[kind] ?? false) },
      set: { send(.toggled(kind, $0)) }
    )
  }
}

#Preview {
  NotificationSettingsView(store: Store(initialState: NotificationSettingsFeature.State()) {
    NotificationSettingsFeature()
  })
}
