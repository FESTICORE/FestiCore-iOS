//
//  FCSetSheet.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 셋 상세 바텀시트 내용. `presentFCSheet`로 띄운다.
///
/// 내 일정 여부는 `isScheduled`로 정하고, 겹침·변경·종료는 `state`로 정한다.
public struct FCSetSheet: View {
  public enum State: Equatable, Sendable {
    case `default`
    /// 내 일정끼리 겹침. `warning`에 겹치는 공연을 적는다.
    case overlap(warning: String)
    /// 시간 변경
    case changed(oldTime: String, change: String)
    /// 공연 종료. 내 일정에 넣을 수 없다.
    case ended
  }

  @Binding private var isScheduled: Bool
  private var artist: String
  private var stage: String
  private var time: String
  private var relativeTime: String
  private(set) var state: State = .default
  private(set) var memo: String?
  private(set) var source: String?
  private(set) var stageAction: (() -> Void)?
  private(set) var scheduleTitle = "내 일정에 넣기"
  private(set) var scheduleHelper = "공연 10분 전에 알려 드려요"
  private(set) var endedTitle = "공연 종료"
  private(set) var endedHelper = "이미 종료된 공연이에요"
  private(set) var isScheduleDisabled = false

  public init(
    artist: String,
    stage: String,
    time: String,
    relativeTime: String,
    isScheduled: Binding<Bool>
  ) {
    self.artist = artist
    self.stage = stage
    self.time = time
    self.relativeTime = relativeTime
    _isScheduled = isScheduled
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      if !tags.isEmpty {
        HStack(spacing: FestiCoreSpacing.paddingP4) {
          ForEach(tags, id: \.self) { tag in
            FCTag(tag)
              .tone(tag == "내 일정" ? .lime : .warning)
          }
        }
      }
      titleRow
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        stageRow
        timeRow
      }
      if case let .overlap(warning) = state {
        warningBox(warning)
      }
      if let memo {
        memoBox(memo)
      }
      scheduleRow
      if let source {
        FCSourceLine(source)
      }
    }
    .padding(.top, FestiCoreSpacing.paddingP16)
    .padding(.horizontal, FestiCoreSpacing.paddingP20)
    .padding(.bottom, FestiCoreSpacing.paddingP20)
  }

  private var isEnded: Bool {
    state == .ended
  }

  private var tags: [String] {
    switch state {
    case .default:
      return isScheduled ? ["내 일정"] : []
    case .overlap:
      return isScheduled ? ["내 일정", "겹침"] : ["겹침"]
    case let .changed(_, change):
      return [change]
    case .ended:
      return []
    }
  }

  private var titleRow: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      Text(artist)
        .festiCoreFont(.baseTitle1Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
      Text(isEnded ? endedTitle : relativeTime)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(
          isEnded
            ? FestiCoreSemanticColor.labelAssistive.color
            : FestiCoreSemanticColor.inverseLabel.color
        )
        .padding(.vertical, FestiCoreSpacing.paddingP4)
        .padding(.horizontal, FestiCoreSpacing.paddingP8)
        .background(
          isEnded
            ? FestiCoreSemanticColor.fillNormal.color
            : FestiCoreSemanticColor.inverseBackground.color,
          in: Capsule()
        )
    }
  }

  @ViewBuilder
  private var stageRow: some View {
    if let stageAction {
      Button(action: stageAction) {
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          stageLabel
          Image(asset: .chevronRight16)
            .resizable()
            .frame(width: Metric.smallIconSize, height: Metric.smallIconSize)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            .accessibilityHidden(true)
        }
      }
      .buttonStyle(.plain)
    } else {
      stageLabel
    }
  }

  private var stageLabel: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      icon(.locationDot20)
      Text(stage)
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
    }
  }

  private var timeRow: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      icon(.clock20)
      if case let .changed(oldTime, _) = state {
        Group {
          Text(oldTime)
          Text("→")
        }
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        Text(time)
          .festiCoreFont(.baseHeadlineBold)
          .foregroundStyle(FestiCoreSemanticColor.accentForegroundOrange.color)
      } else {
        Text(time)
          .festiCoreFont(.baseBodyRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      }
    }
  }

  private func warningBox(_ warning: String) -> some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Image(asset: .triangleExclamation16)
        .resizable()
        .frame(width: Metric.smallIconSize, height: Metric.smallIconSize)
        .foregroundStyle(FestiCoreSemanticColor.accentForegroundOrange.color)
        .accessibilityHidden(true)
      Text(warning)
        .festiCoreFont(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .background(
      FestiCoreSemanticColor.accentBackgroundOrange.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    )
  }

  private func memoBox(_ memo: String) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
      Text("한 줄 메모")
        .festiCoreFont(.baseCaption1Regular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      Text(memo)
        .festiCoreFont(.baseCalloutRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(FestiCoreSpacing.paddingP16)
    .background(
      FestiCoreSemanticColor.fillNormal.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    )
  }

  private var scheduleRow: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(scheduleTitle)
          .festiCoreFont(.baseCalloutBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(isEnded ? endedHelper : scheduleHelper)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      FCToggle(
        isOn: $isScheduled,
        accessibilityLabel: scheduleTitle
      )
      .disabled(isEnded || isScheduleDisabled)
      .opacity(isEnded || isScheduleDisabled ? Metric.disabledOpacity : 1)
    }
  }

  private func icon(_ asset: ImageAsset) -> some View {
    Image(asset: asset)
      .resizable()
      .frame(width: Metric.iconSize, height: Metric.iconSize)
      .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      .accessibilityHidden(true)
  }
}

// MARK: - 체이닝 설정

public extension FCSetSheet {
  /// 겹침·변경·종료 상태를 바꾼 사본을 돌려준다.
  func state(_ state: State) -> Self {
    var copy = self
    copy.state = state
    return copy
  }

  /// 한 줄 메모를 넣은 사본을 돌려준다. nil이면 숨긴다.
  func memo(_ memo: String?) -> Self {
    var copy = self
    copy.memo = memo
    return copy
  }

  /// 아래 출처 줄을 넣은 사본을 돌려준다.
  func source(_ source: String?) -> Self {
    var copy = self
    copy.source = source
    return copy
  }

  /// 무대 줄을 누를 수 있게 한 사본을 돌려준다.
  func stageAction(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.stageAction = action
    return copy
  }

  /// 내 일정 줄의 제목·도움말을 바꾼 사본을 돌려준다.
  func scheduleTexts(
    title: String,
    helper: String
  ) -> Self {
    var copy = self
    copy.scheduleTitle = title
    copy.scheduleHelper = helper
    return copy
  }

  /// 내 일정 토글을 잠시 끈 사본을 돌려준다(불러오는 중 등).
  func scheduleDisabled(_ isDisabled: Bool) -> Self {
    var copy = self
    copy.isScheduleDisabled = isDisabled
    return copy
  }
}

private extension FCSetSheet {
  enum Metric {
    static let iconSize: CGFloat = 20
    static let smallIconSize: CGFloat = 16
    static let disabledOpacity = 0.3
  }
}

#Preview {
  @Previewable
  @State var isScheduled = true

  ScrollView {
    VStack(spacing: FestiCoreSpacing.paddingP24) {
      FCSetSheet(
        artist: "라임플래그스",
        stage: "리벳 스테이지",
        time: "17:00–17:50 · 50분",
        relativeTime: "1시간 32분 후",
        isScheduled: $isScheduled
      )
      .memo("앵콜 없이 정시에 끝나요. 리벳 앞 왼쪽이 덜 붐벼요.")
      .source("출처: 주최측 공지 · 확인 10/16 14:00")
      .stageAction {}
      FCSetSheet(
        artist: "라임플래그스",
        stage: "리벳 스테이지",
        time: "17:00–17:50 · 50분",
        relativeTime: "1시간 32분 후",
        isScheduled: $isScheduled
      )
      .state(.overlap(warning: "크라잉버드(원더 스테이지 15:55–16:45)와 35분 겹쳐요"))
      FCSetSheet(
        artist: "라임플래그스",
        stage: "리벳 스테이지",
        time: "17:00–17:50 · 50분",
        relativeTime: "1시간 32분 후",
        isScheduled: $isScheduled
      )
      .state(
        .changed(
          oldTime: "16:40",
          change: "20분 미뤄짐"
        )
      )
      FCSetSheet(
        artist: "라임플래그스",
        stage: "리벳 스테이지",
        time: "17:00–17:50 · 50분",
        relativeTime: "",
        isScheduled: .constant(false)
      )
      .state(.ended)
    }
  }
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
