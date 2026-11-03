//
//  TimetableSetDetailView.swift
//  Timetable
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

@ViewAction(for: TimetableSetDetailFeature.self)
public struct TimetableSetDetailView: View {
  @Bindable public var store: StoreOf<TimetableSetDetailFeature>

  public init(store: StoreOf<TimetableSetDetailFeature>) {
    self.store = store
  }

  public var body: some View {
    // 열린 동안 공연 시작·종료 시각이 지나면 상태가 바뀌도록 매분 다시 그린다.
    TimelineView(.everyMinute) { context in
      setSheet(store.state.detail(now: context.date))
    }
  }
}

extension TimetableSetDetailView {
  private func setSheet(_ detail: TimetableSetDetail) -> some View {
    FCSetSheet(
      artist: detail.artist,
      stage: detail.stage,
      time: detail.time,
      relativeTime: detail.relativeTime,
      isScheduled: Binding(
        get: { detail.isScheduled },
        set: { _ in send(.scheduleToggled) }
      )
    )
    .state(sheetState(detail))
    .scheduleTexts(
      title: "내 일정에 넣기",
      helper: scheduleHelper
    )
    .scheduleDisabled(store.content.isScheduleLoading)
    .artistImage(detail.imageURL)
    .source(store.content.source.isEmpty ? nil : store.content.source)
  }

  private func sheetState(_ detail: TimetableSetDetail) -> FCSetSheet.State {
    if detail.status == .ended {
      return .ended
    }
    if let overlap = detail.overlap {
      return .overlap(warning: overlap.warning)
    }
    if let previousTime = detail.previousTime, let change = detail.change {
      return .changed(oldTime: previousTime, change: change)
    }
    return .default
  }

  /// 알림 기능 전까지는 저장된다는 사실만 안내한다.
  private var scheduleHelper: String {
    if store.content.isScheduleLoading {
      return "내 일정을 불러오는 중이에요"
    }
    if store.content.isScheduleLimitReached {
      return "내 일정은 최대 \(TimetableFeature.scheduleLimit)개까지 저장할 수 있어요"
    }
    return "내 일정에 저장돼요"
  }
}

#Preview {
  TimetableSetDetailView(
    store: Store(
      initialState: TimetableSetDetailFeature.State(
        setID: "lime",
        content: .init(
          detail: TimetableSetDetail(
            artist: "라임",
            stage: "메인 스테이지",
            time: "17:00–17:50 · 50분",
            status: .upcoming(minutes: 30),
            isScheduled: false
          ),
          interval: DateInterval(start: .now.addingTimeInterval(30 * 60), duration: 50 * 60),
          source: "",
          isScheduleLoading: false,
          isScheduleLimitReached: false
        )
      )
    ) {
      TimetableSetDetailFeature()
    }
  )
}
