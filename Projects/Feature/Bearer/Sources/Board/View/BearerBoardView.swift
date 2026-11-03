//
//  BearerBoardView.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// Figma S09 기수 보드(다크 고정)
@ViewAction(for: BearerBoardFeature.self)
public struct BearerBoardView: View {
  @Bindable public var store: StoreOf<BearerBoardFeature>

  public init(store: StoreOf<BearerBoardFeature>) {
    self.store = store
  }

  public var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { timeline in
      VStack(alignment: .leading, spacing: .zero) {
        topRow
        if store.isOffline {
          FCOfflineBadge("오프라인 · \(relativeText(store.lastSyncedAt, now: timeline.date)) 정보")
        }
        if let current = store.current, let board = store.board {
          content(current: current, board: board, now: timeline.date)
        } else if store.loadFailed {
          failedContent
        } else {
          loadingContent
        }
      }
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color.ignoresSafeArea())
    .overlay {
      if let check = store.check {
        FCCheckOverlay(FCCheckOverlay.Item(title: check.title, message: check.message))
          .ignoresSafeArea()
          .transition(.opacity)
      }
    }
    .animation(.easeOut(duration: 0.2), value: store.check)
    .sensoryFeedback(.success, trigger: store.check?.id) { _, new in new != nil }
    .fcModal($store.scope(state: \.destination?.zonePicker, action: \.destination.zonePicker)) { store in
      BearerZonePickerView(store: store)
        .environment(\.colorScheme, .dark)
    }
    .fcModal($store.scope(state: \.destination?.activityPicker, action: \.destination.activityPicker)) { store in
      BearerActivityPickerView(store: store)
        .environment(\.colorScheme, .dark)
    }
    .fcAlert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .fcAlert($store.scope(state: \.destination?.closeConfirm, action: \.destination.closeConfirm))
    .environment(\.colorScheme, .dark)
    .onAppear { send(.onAppear) }
    .onDisappear { send(.onDisappear) }
  }
}

extension BearerBoardView {
  private var topRow: some View {
    HStack {
      FCBackPill("관객 화면으로") { send(.closeTapped) }
      Spacer()
      Text("기수 모드")
        .festiCoreFont(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .padding(.vertical, FestiCoreSpacing.paddingP12)
  }

  private func content(current: BearerBoardFeature.Current, board: BearerBoard, now: Date) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      header(current: current, board: board, now: now)
      Group {
        switch current.lifecycle {
        case .scheduled:
          FCBearerCTA(.start) { send(.raiseTapped) }
            .frame(maxHeight: .infinity)
        case .ended:
          restartCTA
            .frame(maxHeight: .infinity)
        case .active, .resting:
          tiles(current)
        }
      }
      if let message = store.errorMessage {
        HStack(spacing: FestiCoreSpacing.marginM8) {
          Text(message)
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
            .frame(maxWidth: .infinity, alignment: .leading)
          if store.isSendPaused {
            FCButton("다시 보내기") { send(.retrySendTapped) }
              .style(.secondary)
              .size(.medium)
          }
        }
      }
      FCBearerFooter(queuedCount: store.pending.count)
        .padding(.horizontal, -FestiCoreSpacing.paddingP16)
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .padding(.top, FestiCoreSpacing.paddingP8)
  }

  private func header(current: BearerBoardFeature.Current, board: BearerBoard, now: Date) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM8) {
      Text(board.profile.name)
        .festiCoreFont(.baseTitle1Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
        .lineLimit(1)
      HStack(spacing: FestiCoreSpacing.marginM8) {
        FCStatusChip(statusChip(current.lifecycle))
        Text(summary(current, now: now))
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .lineLimit(1)
      }
      if let other = store.changedByOtherBearer {
        HStack(spacing: FestiCoreSpacing.marginM6) {
          Text(String(other.nickname.prefix(1)))
            .festiCoreFont(.baseCaption2Bold)
            .foregroundStyle(FestiCoreSemanticColor.accentForegroundPurple.color)
            .frame(width: 20, height: 20)
            .background(FestiCoreSemanticColor.accentBackgroundPurple.color, in: Circle())
            .accessibilityHidden(true)
          Text("\(other.nickname.isEmpty ? "공동 기수" : other.nickname)".withIga + " \(changedTimeText(current.updatedAt, now: now)) 바꿨어요")
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        }
      }
      Text("팔로워 \(board.followerCount.formatted())명이 보고 있어요")
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
  }

  private func tiles(_ current: BearerBoardFeature.Current) -> some View {
    let isResting = current.lifecycle == .resting
    return Grid(horizontalSpacing: FestiCoreSpacing.marginM12, verticalSpacing: FestiCoreSpacing.marginM12) {
      GridRow {
        FCBigButton("존", sub: store.state.zoneName(for: current.zoneID) ?? "존 고르기", icon: .locationDot20) {
          send(.zoneTapped)
        }
        FCBigButton("활동", sub: (current.activity ?? store.lastActivity)?.title ?? "활동 고르기", icon: .music24) {
          send(.activityTapped)
        }
        .isSelected(!isResting)
      }
      GridRow {
        if isResting {
          FCBigButton("다시 시작", sub: "활동 중으로 돌아가요", icon: .clock20) { send(.resumeTapped) }
            .isSelected(true)
        } else {
          FCBigButton("쉬는 중", sub: "탭 한 번", icon: .clock20) { send(.restTapped) }
        }
        FCBigButton("종료", sub: "오늘 깃발 내리기", icon: .circleXmark) { send(.endTapped) }
      }
    }
    .frame(maxHeight: .infinity)
  }

  @ViewBuilder
  private var restartCTA: some View {
    if store.restartUsedToday {
      FCBearerCTA(.restart) {}
        .copy(.init(
          title: "오늘 깃발을 내렸어요",
          buttonTitle: "다시 시작하기",
          caption: "오늘은 이미 다시 시작했어요",
          note: "내일 다시 올릴 수 있어요"
        ))
        .disabled(true)
        .opacity(FestiCoreState.disabledOpacity)
    } else {
      FCBearerCTA(.restart) { send(.restartTapped) }
    }
  }

  private var loadingContent: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      FCSkeletonView(.round()).frame(width: 160, height: 32)
      FCSkeletonView(.round()).frame(width: 240, height: 20)
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r24)).frame(maxHeight: .infinity)
    }
    .padding(FestiCoreSpacing.paddingP16)
  }

  private var failedContent: some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      Text(store.errorMessage ?? "기수 보드를 불러오지 못했어요")
        .festiCoreFont(.baseBodyMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .multilineTextAlignment(.center)
      FCButton("다시 시도") { send(.retryTapped) }
        .style(.secondary)
        .size(.medium)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(FestiCoreSpacing.paddingP16)
  }

  private func statusChip(_ lifecycle: BearerFlagLifecycle) -> FCStatusChip.Status {
    switch lifecycle {
    case .scheduled: return .scheduled
    case .active: return .active
    case .resting: return .resting
    case .ended: return .endedToday
    }
  }

  private func summary(_ current: BearerBoardFeature.Current, now: Date) -> String {
    let time = relativeText(current.updatedAt, now: now)
    switch current.lifecycle {
    case .scheduled:
      return "아직 깃발을 올리지 않았어요"
    case .ended:
      return "오늘 활동을 마쳤어요 · \(time)"
    case .resting:
      return [store.state.zoneName(for: current.zoneID), "쉬는 중", time].compactMap { $0 }.joined(separator: " · ")
    case .active:
      return [store.state.zoneName(for: current.zoneID), current.activity?.title, time].compactMap { $0 }.joined(separator: " · ")
    }
  }

  private func relativeText(_ date: Date?, now: Date) -> String {
    guard let date else { return "방금" }
    let seconds = max(0, now.timeIntervalSince(date))
    if seconds < 60 { return "방금" }
    if seconds < 3600 { return "\(Int(seconds / 60))분 전" }
    return "\(Int(seconds / 3600))시간 전"
  }

  private func changedTimeText(_ date: Date, now: Date) -> String {
    let text = relativeText(date, now: now)
    return text == "방금" ? "방금" : "\(text)에"
  }
}

#Preview {
  BearerBoardView(store: .init(
    initialState: BearerBoardFeature.State(festivalID: "fst_preview", flagID: "flg_preview", viewerUserID: nil)
  ) {
    BearerBoardFeature()
  })
}
