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
      if store.isPublished, let day = store.selectedDay {
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
        TimetableUnpublishedView(lineup: store.lineup) {
          send(.notifyTapped)
        }
      }
      if !store.source.isEmpty {
        FCSourceLine(store.source)
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
  }
}

private extension TimetableView {
  var header: some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .large,
        title: "타임테이블"
      )
      .trailingAction(
        icon: .magnifyingGlass,
        accessibilityLabel: "검색",
        action: { send(.searchTapped) }
      )
      daySelector
    }
  }

  /// 세그먼트는 칸을 균등 분할해 날짜가 많으면 "1…"로 잘리므로, 넘치면 가로로 넘기는 칩 줄로 보여 준다.
  @ViewBuilder
  var daySelector: some View {
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
    HStack {
      FCChip("내 일정만") {
        send(.mineOnlyToggled)
      }
      .isSelected(store.showsMineOnly)
      Spacer()
      Text("내 일정 \(store.mySetCount)개")
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      FCButton("내 일정 고르기") {
        send(.schedulePickTapped)
      }
      .style(.secondary)
      .size(.medium)
      .isEnabled(store.canPickSchedule)
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
