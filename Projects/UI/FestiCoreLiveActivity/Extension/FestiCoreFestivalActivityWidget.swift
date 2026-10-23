//
//  FestiCoreFestivalActivityWidget.swift
//  FestiCoreLiveActivityExtension
//
//  Created by FestiCore on 10/23/26.
//

import ActivityKit
import FestiCoreLiveActivity
import SwiftUI
import WidgetKit

struct FestiCoreFestivalActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: FestiCoreFestivalActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 8) {
        Text(context.attributes.festivalName)
          .font(.headline)
          .lineLimit(1)
        Text(context.isStale ? "축제 정보를 확인해 주세요" : statusText(for: context.state))
          .font(.subheadline)
        if context.state.phase == .upcoming {
          Text(context.state.startDate, style: .date)
            .font(.caption)
        }
      }
      .padding()
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "sparkles")
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.attributes.festivalName)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.isStale ? "축제 정보를 확인해 주세요" : statusText(for: context.state))
        }
      } compactLeading: {
        Image(systemName: "sparkles")
      } compactTrailing: {
        Text(shortStatusText(for: context.state))
      } minimal: {
        Image(systemName: "sparkles")
      }
    }
  }

  private func statusText(for state: FestiCoreFestivalActivityAttributes.ContentState) -> String {
    switch state.phase {
    case .upcoming: "곧 시작하는 축제"
    case .ongoing: "진행 중인 축제"
    case .finished: "종료된 축제"
    }
  }

  private func shortStatusText(for state: FestiCoreFestivalActivityAttributes.ContentState) -> String {
    switch state.phase {
    case .upcoming: "예정"
    case .ongoing: "진행"
    case .finished: "종료"
    }
  }
}
