//
//  TimetableView.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
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
          state: store.state,
          day: day,
          onSetTap: { send(.setTapped($0)) }
        )
      } else {
        TimetableUnpublishedView(lineup: store.lineup) {
          send(.notifyTapped)
        }
      }
      FCSourceLine(store.source)
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
  }

  private var header: some View {
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
      FCSegmented(
        selection: Binding(
          get: { store.selectedDayIndex },
          set: { send(.daySelected($0)) }
        ),
        items: store.days.map(\.title)
      )
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
    }
  }

  private var filter: some View {
    HStack {
      FCChip("내 일정만") {
        send(.mineOnlyToggled)
      }
      .isSelected(store.showsMineOnly)
      Spacer()
      Text("내 일정 \(store.mySetCount)개")
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
    .padding(FestiCoreSpacing.paddingP16)
  }
}

#Preview("A. 기본") {
  TimetableView(store: Store(initialState: .sample()) { TimetableFeature() })
}

#Preview("B. 내 일정만") {
  TimetableView(store: Store(initialState: .sample(showsMineOnly: true)) { TimetableFeature() })
}

#Preview("C. 시간표 변경") {
  TimetableView(store: Store(initialState: .sample(variant: .changed)) { TimetableFeature() })
}

#Preview("D. 일정 겹침") {
  TimetableView(store: Store(initialState: .sample(variant: .overlap)) { TimetableFeature() })
}

#Preview("E. 시간표 공개 전") {
  TimetableView(store: Store(initialState: .sample(variant: .unpublished)) { TimetableFeature() })
}

#Preview("F. 무대 3개") {
  TimetableView(store: Store(initialState: .sample(variant: .threeStages)) { TimetableFeature() })
}

#Preview("G. 오프라인") {
  TimetableView(store: Store(initialState: .sample(variant: .offline)) { TimetableFeature() })
}
