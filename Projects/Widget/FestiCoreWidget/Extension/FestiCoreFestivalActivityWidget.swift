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
    return ActivityConfiguration(for: FestiCoreFestivalActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 8) {
        Text(context.attributes.festivalName)
          .font(.headline)
          .lineLimit(1)
        Text(context.isStale ? "축제 정보를 확인해 주세요" : statusText(for: context.state))
          .font(.subheadline)
        performanceSummary(for: context.state)
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
          VStack(alignment: .leading, spacing: 4) {
            Text(context.isStale ? "축제 정보를 확인해 주세요" : statusText(for: context.state))
            performanceSummary(for: context.state)
          }
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

}

private extension FestiCoreFestivalActivityWidget {
  @ViewBuilder
  func performanceSummary(
    for state: FestiCoreFestivalActivityAttributes.ContentState
  ) -> some View {
    if let next = state.nextMine {
      Text("내 다음 공연")
        .font(.caption)
      Text(next.artist)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
      Text("\(next.stageId) · \(startTime(next.startsAt))")
        .font(.caption)
        .lineLimit(1)
    } else if let current = state.nowStages.first {
      Text("지금 공연 중")
        .font(.caption)
      Text("\(current.artist) · \(current.stageId)")
        .font(.subheadline)
        .lineLimit(1)
    } else if state.phase == .upcoming {
      Text(state.startDate, style: .date)
        .font(.caption)
    }
  }

  func startTime(_ value: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: value) ?? {
      formatter.formatOptions = [.withInternetDateTime]
      return formatter.date(from: value)
    }()
    return date?.formatted(date: .omitted, time: .shortened) ?? value
  }

  func statusText(for state: FestiCoreFestivalActivityAttributes.ContentState) -> String {
    switch state.phase {
    case .upcoming:
      return "곧 시작하는 축제"
    case .ongoing:
      return "진행 중인 축제"
    case .finished:
      return "종료된 축제"
    }
  }

  func shortStatusText(for state: FestiCoreFestivalActivityAttributes.ContentState) -> String {
    switch state.phase {
    case .upcoming:
      return "예정"
    case .ongoing:
      return "진행"
    case .finished:
      return "종료"
    }
  }
}
