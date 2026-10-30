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

  /// 탭바까지 포함한 상위 화면에서 시트를 표시한다.
  public var modalOverlay: some View {
    Color.clear.presentFCSheet(
      item: Binding(
        get: { store.selectedSetID.map(SelectedSet.init) },
        set: { if $0 == nil { send(.setDetailDismissed) } }
      )
    ) { _ in
      // 열린 동안 공연 시작·종료 시각이 지나면 상태가 바뀌도록 매분 다시 그린다.
      TimelineView(.everyMinute) { context in
        if let detail = store.state.setDetail(now: context.date) {
          setSheet(detail)
        }
      }
    }
  }
}

private extension TimetableView {
  func setSheet(_ detail: TimetableSetDetail) -> some View {
    FCSetSheet(
      artist: detail.artist,
      stage: detail.stage,
      time: detail.time,
      relativeTime: detail.relativeTime,
      isScheduled: Binding(
        get: { detail.isScheduled },
        set: { _ in send(.setScheduleToggled) }
      )
    )
    .state(sheetState(detail))
    .scheduleTexts(
      title: "내 일정에 넣기",
      helper: scheduleHelper
    )
    .scheduleDisabled(store.scheduleSync == .loading)
  }

  func sheetState(_ detail: TimetableSetDetail) -> FCSetSheet.State {
    if detail.status == .ended {
      return .ended
    }
    if let artist = detail.overlappingArtists.first {
      return .overlap(warning: "\(artist) 공연과 시간이 겹쳐요")
    }
    if let previousTime = detail.previousTime, let change = detail.change {
      return .changed(oldTime: previousTime, change: change)
    }
    return .default
  }

  /// 알림 기능 전까지는 저장된다는 사실만 안내한다.
  var scheduleHelper: String {
    if store.scheduleSync == .loading {
      return "내 일정을 불러오는 중이에요"
    }
    if store.isScheduleLimitReached {
      return "내 일정은 최대 \(TimetableFeature.scheduleLimit)개까지 저장할 수 있어요"
    }
    return "내 일정에 저장돼요"
  }

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
    }
    .padding(FestiCoreSpacing.paddingP16)
  }
}

private struct SelectedSet: Identifiable, Equatable {
  let id: String
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
