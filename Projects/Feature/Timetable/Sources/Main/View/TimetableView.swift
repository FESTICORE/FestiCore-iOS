//
//  TimetableView.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

@ViewAction(for: TimetableFeature.self)
public struct TimetableView: View {
  @Bindable public var store: StoreOf<TimetableFeature>

  public init(store: StoreOf<TimetableFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      header
      if let offlineMessage = store.offlineMessage {
        FCOfflineBadge(offlineMessage)
      }
      content()
      if !store.source.isEmpty {
        FCSourceLine(store.source)
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .task { await send(.clockStarted).finish() }
    .onDisappear { send(.clockStopped) }
  }
}

private extension TimetableView {
  @ViewBuilder
  func content() -> some View {
    switch store.contentStatus {
    case .loading:
      skeleton
    case .failed:
      FCEmptyCard(
        icon: .bell,
        title: "시간표를 불러오지 못했어요",
        message: "연결 상태를 확인하고 다시 시도해 주세요."
      )
      .action(
        FCCardAction(
          "다시 시도",
          style: .primary,
          action: { send(.retryTapped) }
        )
      )
      .padding(FestiCoreSpacing.paddingP16)
    case .noFestival:
      FCEmptyCard(
        icon: .magnifyingGlass,
        title: "축제를 선택해 주세요",
        message: "참여할 축제를 선택하면 시간표를 볼 수 있어요."
      )
      .padding(FestiCoreSpacing.paddingP16)
    case .unpublished:
      TimetableUnpublishedView(lineup: store.lineup) { send(.notifyTapped) }
    case .published:
      if let day = store.selectedDay {
        filter
        if day.changedCount > 0 {
          FCBanner("시간표가 바뀌었어요 · \(day.changedCount)개 변경") {
            send(.changeBannerTapped)
          }
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
          .padding(.bottom, FestiCoreSpacing.paddingP16)
        }
        TimetableBoard(
          store: store,
          day: day,
          onSetTap: { send(.setTapped($0)) },
          onZoomEnd: { send(.zoomChanged($0)) },
          onDaySwipe: { send(.daySelected(store.selectedDayIndex + $0)) }
        )
      } else {
        FCEmptyCard(
          icon: .bell,
          title: "등록된 공연이 없어요",
          message: "공연 정보가 등록되면 시간표에서 확인할 수 있어요."
        )
        .padding(FestiCoreSpacing.paddingP16)
      }
    }
  }

  var skeleton: some View {
    return VStack(spacing: FestiCoreSpacing.paddingP16) {
      ForEach(0..<3, id: \.self) { _ in
        FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
          .frame(height: 120)
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
  }

  var header: some View {
    return VStack(spacing: .zero) {
      FCTopBar(
        .large,
        title: "타임테이블"
      )
      .trailingAction(
        icon: .magnifyingGlass,
        accessibilityLabel: "검색",
        action: { send(.searchTapped) }
      )
      if !store.days.isEmpty { daySelector() }
    }
  }

  /// 세그먼트는 칸을 균등 분할해 날짜가 많으면 "1…"로 잘리므로, 넘치면 가로로 넘기는 칩 줄로 보여 준다.
  @ViewBuilder
  func daySelector() -> some View {
    if store.days.count <= Metric.segmentedDayLimit {
      FCSegmented(
        selection: Binding(
          get: { store.selectedDayIndex },
          set: { send(.daySelected($0)) }
        ),
        items: store.days.map(\.title)
      )
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
    } else {
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          HStack(spacing: FestiCoreSpacing.paddingP8) {
            ForEach(Array(store.days.enumerated()), id: \.offset) { index, day in
              FCChip(day.title) {
                send(.daySelected(index))
              }
              .isSelected(index == store.selectedDayIndex)
              .id(index)
            }
          }
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
        }
        .scrollIndicators(.hidden)
        .onAppear { proxy.scrollTo(store.selectedDayIndex, anchor: .center) }
        .onChange(of: store.selectedDayIndex) { _, index in
          withAnimation { proxy.scrollTo(index, anchor: .center) }
        }
      }
    }
  }

  var filter: some View {
    return HStack {
      FCChip("내 일정만") {
        send(.mineOnlyToggled)
      }
      .isSelected(store.showsMineOnly)
      Spacer()
      Button {
        send(.schedulePickTapped)
      } label: {
        Text(store.overlaps.isEmpty ? "내 일정 \(store.mySetCount)개" : "겹치는 일정 \(store.overlaps.count)개")
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(
            store.overlaps.isEmpty
              ? FestiCoreSemanticColor.labelAssistive.color
              : FestiCoreSemanticColor.accentPointOrange.color
          )
      }
      .buttonStyle(.plain)
      .disabled(!store.canPickSchedule)
      .accessibilityLabel("내 일정 고르기")
    }
    .padding(FestiCoreSpacing.paddingP16)
  }
}

private extension TimetableView {
  enum Metric {
    /// `FCSegmented`가 잘리지 않고 담는 날짜 수(2~3칸용)
    static let segmentedDayLimit = 3
  }
}

#Preview {
  TimetableView(store: Store(initialState: TimetableFeature.State(days: [], source: "")) { TimetableFeature() })
}
