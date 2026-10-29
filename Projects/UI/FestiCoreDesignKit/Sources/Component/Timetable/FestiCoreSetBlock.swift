//
//  FestiCoreSetBlock.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 타임테이블의 셋 블록. 높이는 공연 길이(1분 2pt)이고 부모가 정한다.
///
/// 블록이 짧으면 태그 → 시간 → 여백 순으로 덜어 내고, 24pt 미만이면 글자를 그리지 않는다.
public struct FestiCoreSetBlock: View {
  public enum State: Equatable, Sendable {
    case `default`
    /// 내 일정
    case mine
    /// 시간 변경
    case changed(oldTime: String, change: String)
    /// 내 일정끼리 겹침
    case overlap(label: String = "겹침")
  }

  private var artist: String
  private var time: String
  private(set) var state: State = .default

  public init(artist: String, time: String) {
    self.artist = artist
    self.time = time
  }

  /// 공연 길이에 맞는 블록 높이. 0 이하는 0이다.
  public static func height(minutes: Int) -> CGFloat {
    CGFloat(max(0, minutes)) * Metric.pointsPerMinute
  }

  public var body: some View {
    ViewThatFits(in: .vertical) {
      content(showsTime: true, showsTag: true)
        .padding(contentInsets)
      content(showsTime: true, showsTag: false)
        .padding(contentInsets)
      content(showsTime: false, showsTag: false)
        .padding(contentInsets)
      artistText(style: .baseCaption1Bold)
        .padding(.vertical, FestiCoreSpacing.paddingP4)
        .padding(.horizontal, FestiCoreSpacing.paddingP12)
      Color.clear
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(backgroundColor.color)
    .overlay(alignment: .leading) {
      if case .changed = state {
        FestiCoreSemanticColor.accentPointOrange.color
          .frame(width: Metric.changedBorderWidth)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
    .overlay {
      if state == .default {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
          .strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: Metric.borderWidth)
      }
    }
    .overlay(alignment: .topTrailing) {
      if state == .mine {
        checkMark
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(artist)
    .accessibilityValue(accessibilityValue)
  }

  private func content(showsTime: Bool, showsTag: Bool) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
      artistText(style: .baseCalloutBold)
      if showsTime {
        timeRow
      }
      if showsTag {
        tag
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func artistText(style: FestiCoreTextStyle) -> some View {
    Text(artist)
      .festiCoreFont(style)
      .foregroundStyle(artistColor.color)
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var timeRow: some View {
    if case let .changed(oldTime, _) = state {
      HStack(spacing: FestiCoreSpacing.paddingP4) {
        Text(oldTime)
          .strikethrough()
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        Text("→")
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        Text(time)
          .festiCoreFont(.baseCaption1Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
      }
      .lineLimit(1)
    } else {
      Text(time)
        .festiCoreFont(.baseCaption1Regular)
        .foregroundStyle(timeColor.color)
        .lineLimit(1)
    }
  }

  @ViewBuilder
  private var tag: some View {
    switch state {
    case let .changed(_, change):
      Text(change)
        .festiCoreFont(.baseCaption2Bold)
        .foregroundStyle(FestiCoreSemanticColor.accentForegroundOrange.color)
        .padding(.vertical, FestiCoreSpacing.marginM2)
        .padding(.horizontal, FestiCoreSpacing.marginM6)
        .background(
          FestiCoreSemanticColor.accentBackgroundOrange.color,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r4)
        )
    case let .overlap(label):
      Text(label)
        .festiCoreFont(.baseCaption2Bold)
        .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
        .padding(.vertical, FestiCoreSpacing.marginM2)
        .padding(.horizontal, FestiCoreSpacing.marginM6)
        .background(
          FestiCoreSemanticColor.accentPointOrange.color,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r8)
        )
    case .default, .mine:
      EmptyView()
    }
  }

  private var checkMark: some View {
    Image(asset: .check)
      .resizable()
      .frame(width: Metric.checkIconSize, height: Metric.checkIconSize)
      .foregroundStyle(FestiCoreSemanticColor.staticLime.color)
      .frame(width: Metric.checkSize, height: Metric.checkSize)
      .background(FestiCoreSemanticColor.staticInk.color, in: Circle())
      .padding(FestiCoreSpacing.paddingP8)
  }

  private var contentInsets: EdgeInsets {
    EdgeInsets(
      top: FestiCoreSpacing.paddingP12,
      leading: FestiCoreSpacing.paddingP12,
      bottom: FestiCoreSpacing.paddingP12,
      trailing: state == .mine ? FestiCoreSpacing.paddingP24 : FestiCoreSpacing.paddingP12
    )
  }

  private var isOnLime: Bool {
    switch state {
    case .mine, .overlap: return true
    case .default, .changed: return false
    }
  }

  private var backgroundColor: FestiCoreSemanticColor {
    isOnLime ? .accentPointLime : .backgroundElevated
  }

  private var artistColor: FestiCoreSemanticColor {
    isOnLime ? .staticInk : .labelNormal
  }

  private var timeColor: FestiCoreSemanticColor {
    isOnLime ? .staticalphaBlack60 : .labelAssistive
  }

  var accessibilityValue: String {
    switch state {
    case .default: return time
    case .mine: return "\(time), 내 일정"
    case let .changed(oldTime, change): return "\(time), 변경 전 \(oldTime), \(change)"
    case let .overlap(label): return "\(time), \(label)"
    }
  }
}

// MARK: - 체이닝 설정
public extension FestiCoreSetBlock {
  /// `state` 를 바꾼 사본을 돌려준다.
  func state(_ state: State) -> Self {
    var copy = self
    copy.state = state
    return copy
  }
}

private extension FestiCoreSetBlock {
  enum Metric {
    static let pointsPerMinute: CGFloat = 2
    static let borderWidth: CGFloat = 1
    static let changedBorderWidth: CGFloat = 3
    static let checkSize: CGFloat = 20
    static let checkIconSize: CGFloat = 12
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP8) {
    FestiCoreSetBlock(artist: "아티스트", time: "18:00 - 19:00")
      .frame(height: FestiCoreSetBlock.height(minutes: 60))
    FestiCoreSetBlock(artist: "아티스트", time: "18:00 - 19:00")
      .state(.mine)
      .frame(height: FestiCoreSetBlock.height(minutes: 60))
    FestiCoreSetBlock(artist: "아티스트", time: "18:30 - 19:30")
      .state(.changed(oldTime: "18:00", change: "30분 지연"))
      .frame(height: FestiCoreSetBlock.height(minutes: 60))
    FestiCoreSetBlock(artist: "아티스트", time: "18:00 - 18:20")
      .state(.overlap())
      .frame(height: FestiCoreSetBlock.height(minutes: 20))
  }
  .frame(width: 120)
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
