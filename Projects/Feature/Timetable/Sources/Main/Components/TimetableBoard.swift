//
//  TimetableBoard.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI
import TimetableDomainInterface

/// 무대 헤더와 시간 격자. 무대가 3개 이상이면 가로로도 스크롤한다.
/// 두 손가락으로 벌리거나 모으면 시간축을 확대·축소한다.
/// 가로로 스크롤하지 않을 때는 좌우로 밀어 전날·다음 날로 넘긴다.
struct TimetableBoard: View {
  /// 상태 사본을 받으면 배율·현재 시각이 바뀌어도 상위 화면이 다시 그려지기 전까지 이전 값을 쓰므로 Store에서 직접 읽는다.
  let store: StoreOf<TimetableFeature>
  let day: TimetableDay
  let onSetTap: (String) -> Void
  let onZoomEnd: (Double) -> Void
  /// 좌우 스와이프로 옮길 날짜 간격. 다음 날이면 1, 전날이면 -1이다.
  let onDaySwipe: (Int) -> Void

  /// 손가락을 움직이는 동안의 배율. 제스처가 끝나거나 취소되면 1로 돌아가고, 끝날 때만 리듀서에 확정값을 보낸다.
  @GestureState private var gestureMagnification: CGFloat = 1

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(isWide ? [.horizontal, .vertical] : .vertical) {
        LazyVStack(
          spacing: .zero,
          pinnedViews: .sectionHeaders
        ) {
          Section {
            grid
          } header: {
            stageHeaders
          }
        }
        .frame(width: isWide ? wideWidth : nil)
      }
      .scrollIndicators(.hidden)
      .task(id: day.id) {
        guard let now = store.nowMinute else { return }
        await Task.yield()
        proxy.scrollTo(
          now / 60,
          anchor: .top
        )
      }
    }
    .simultaneousGesture(
      MagnifyGesture()
        .updating($gestureMagnification) { value, magnification, _ in
          magnification = value.magnification
        }
        .onEnded { value in
          onZoomEnd(Double(clampedZoom(value.magnification)))
        }
    )
    // 가로로 스크롤하는 보드에서는 스와이프가 스크롤과 겹치므로 붙이지 않는다.
    .simultaneousGesture(daySwipe, including: isWide ? .subviews : .all)
  }
}

extension TimetableBoard {
  /// 날짜를 넘길 스와이프인지 판정한다. 가로로 80 이상, 세로의 1.5배를 넘게 밀었을 때만 반응한다.
  /// - Returns: 왼쪽으로 밀면 다음 날(1), 오른쪽으로 밀면 전날(-1). 아니면 nil.
  static func dayOffset(forSwipe translation: CGSize) -> Int? {
    let horizontal = translation.width
    guard abs(horizontal) > Metric.swipeThreshold,
          abs(horizontal) > abs(translation.height) * Metric.swipeRatio else { return nil }
    return horizontal < 0 ? 1 : -1
  }
}

private extension TimetableBoard {
  var zoom: CGFloat {
    clampedZoom(gestureMagnification)
  }

  func clampedZoom(_ magnification: CGFloat) -> CGFloat {
    min(max(CGFloat(store.zoom) * magnification, Metric.minZoom), Metric.maxZoom)
  }

  var isWide: Bool {
    day.stages.count > Metric.fillingStageCount
  }

  var daySwipe: some Gesture {
    DragGesture(minimumDistance: Metric.swipeMinimumDistance)
      .onEnded { value in
        guard let offset = Self.dayOffset(forSwipe: value.translation) else { return }
        onDaySwipe(offset)
      }
  }

  var startHour: Int {
    (day.sets.map(\.start).min() ?? Metric.defaultStart) / 60
  }

  var endHour: Int {
    let end = day.sets.map(\.end).max() ?? Metric.defaultEnd
    return max(startHour + 1, Int((Double(end) / 60).rounded(.up)))
  }

  var gridHeight: CGFloat {
    y(endHour * 60)
  }

  var wideWidth: CGFloat {
    let count = CGFloat(day.stages.count)
    return Metric.leadingInset + Metric.wideColumnWidth * count
      + FestiCoreSpacing.paddingP8 * (count - 1) + FestiCoreSpacing.paddingP16
  }

  private var stageHeaders: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      ForEach(Array(day.stages.enumerated()), id: \.element.id) { index, stage in
        FCStageHeader(name: stage.name)
          .dotColor(Metric.dotColors[index % Metric.dotColors.count])
          .frame(width: isWide ? Metric.wideColumnWidth : nil)
      }
    }
    .padding(.leading, Metric.leadingInset)
    .padding(.trailing, FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .overlay(alignment: .bottom) {
      FestiCoreSemanticColor.lineNormal.color
        .frame(height: Metric.lineWidth)
    }
  }

  private var grid: some View {
    ZStack(alignment: .topLeading) {
      hourLines
      ForEach(
        Array(store.visibleOverlaps.enumerated()),
        id: \.offset
      ) { _, overlap in
        overlapBand(overlap)
      }
      columns
      if let now = store.nowMinute, (startHour * 60 ... endHour * 60).contains(now) {
        FCNowLine(time: TimetableDay.clock(now))
          .offset(y: y(now) - Metric.nowLineHeight / 2)
      }
    }
    .frame(height: gridHeight, alignment: .topLeading)
    .frame(maxWidth: .infinity, alignment: .leading)
    // 첫 시각 라벨은 선 위로 반만큼 올라가므로 고정된 무대 헤더에 가리지 않게 띄운다.
    .padding(.top, Metric.hourLabelHalfHeight)
  }

  private var hourLines: some View {
    ForEach(startHour ..< endHour, id: \.self) { hour in
      ZStack(alignment: .topLeading) {
        FestiCoreSemanticColor.lineNormal.color
          .frame(height: Metric.lineWidth)
          .padding(.leading, Metric.hourLineInset)
          .padding(.trailing, FestiCoreSpacing.paddingP16)
        Text(TimetableDay.clock(hour * 60))
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .padding(.leading, FestiCoreSpacing.paddingP12)
          .offset(y: -Metric.hourLabelHalfHeight)
      }
      .id(hour)
      .offset(y: y(hour * 60))
    }
  }

  private var columns: some View {
    HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
      ForEach(day.stages) { stage in
        ZStack(alignment: .top) {
          Color.clear
          ForEach(day.sets.filter { $0.stageID == stage.id }) { set in
            block(set)
          }
        }
        .frame(width: isWide ? Metric.wideColumnWidth : nil)
        .frame(maxWidth: isWide ? nil : .infinity)
        .frame(height: gridHeight)
      }
    }
    .padding(.leading, Metric.leadingInset)
    .padding(.trailing, FestiCoreSpacing.paddingP16)
  }

  private func block(_ set: TimetableSet) -> some View {
    Button {
      onSetTap(set.id)
    } label: {
      FCSetBlock(
        artist: set.artist,
        time: set.timeRange
      )
      .state(blockState(set))
      // 축소해도 아주 짧은 공연이 사라지지 않게 최소 높이를 둔다.
      .frame(height: max(Metric.minBlockHeight, y(set.end) - y(set.start) - Metric.blockInset * 2))
    }
    .buttonStyle(.plain)
    .opacity(opacity(set))
    .offset(y: y(set.start) + Metric.blockInset)
  }

  private func overlapBand(_ overlap: TimetableOverlap) -> some View {
    let height = y(overlap.end) - y(overlap.start)

    return ZStack(alignment: .leading) {
      FCOverlapHighlight()
        .clipShape(
          UnevenRoundedRectangle(
            topLeadingRadius: FestiCoreRadius.r4,
            bottomLeadingRadius: FestiCoreRadius.r4
          )
        )
        .padding(.leading, Metric.hourLineInset)
      FestiCoreSemanticColor.accentPointOrange.color
        .frame(width: Metric.overlapBarWidth)
        .clipShape(RoundedRectangle(cornerRadius: Metric.overlapBarWidth))
        .padding(.leading, Metric.overlapBarInset)
      Text("\(overlap.minutes)분\n겹침")
        .festiCoreFont(.baseCaption2Bold)
        .foregroundStyle(FestiCoreSemanticColor.accentPointOrange.color)
        .padding(.leading, FestiCoreSpacing.paddingP12)
    }
    .frame(height: height)
    .offset(y: y(overlap.start))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("내 일정 \(overlap.minutes)분 겹침")
  }

  private func blockState(_ set: TimetableSet) -> FCSetBlock.State {
    if let previousTime = set.previousTime, let change = set.startChange {
      return .changed(
        oldTime: previousTime,
        change: change
      )
    }
    if store.state.isOverlapping(set) {
      return .overlap()
    }
    return store.mySetIDs.contains(set.id) ? .mine : .default
  }

  private func opacity(_ set: TimetableSet) -> Double {
    if store.showsMineOnly && !store.mySetIDs.contains(set.id) {
      return Metric.hiddenOpacity
    }
    if let now = store.nowMinute, set.end <= now {
      return Metric.pastOpacity
    }
    return 1
  }

  private func y(_ minute: Int) -> CGFloat {
    CGFloat(minute - startHour * 60) * Metric.pointsPerMinute * zoom
  }
}

private extension TimetableBoard {
  enum Metric {
    static let pointsPerMinute = FCSetBlock.height(minutes: 1)
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 2
    static let minBlockHeight: CGFloat = 8
    static let fillingStageCount = 2
    static let swipeMinimumDistance: CGFloat = 30
    static let swipeThreshold: CGFloat = 80
    static let swipeRatio: CGFloat = 1.5
    static let defaultStart = 12 * 60
    static let defaultEnd = 24 * 60
    static let leadingInset: CGFloat = 56
    static let hourLineInset: CGFloat = 52
    static let overlapBarInset: CGFloat = 46
    static let overlapBarWidth: CGFloat = 3
    static let wideColumnWidth: CGFloat = 140
    static let blockInset: CGFloat = 2
    static let lineWidth: CGFloat = 1
    static let hourLabelHalfHeight: CGFloat = 8
    static let nowLineHeight: CGFloat = 20
    static let pastOpacity = 0.4
    static let hiddenOpacity = 0.2
    static let dotColors: [FestiCoreSemanticColor] = [.accentPointLime, .accentPointPurple, .accentPointBlue]
  }
}
