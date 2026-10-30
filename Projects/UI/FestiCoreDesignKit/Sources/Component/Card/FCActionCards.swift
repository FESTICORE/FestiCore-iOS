//
//  FCActionCards.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 카드 아래 버튼 하나의 글자와 동작.
public struct FCCardAction {
  public var title: String
  public var style: FCButton.Style
  public var action: () -> Void

  public init(
    _ title: String,
    style: FCButton.Style = .secondary,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.style = style
    self.action = action
  }
}

private struct FCCardActionRow: View {
  let actions: [FCCardAction]

  var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
        FCButton(
          item.title,
          action: item.action
        )
        .style(item.style)
        .size(.medium)
        .isFullWidth(true)
      }
    }
  }
}

/// 내 다음 일정 카드. 라임 바탕에 아티스트·남은 시간·진행 막대를 보인다.
public struct FCNextSetCard: View {
  private var artist: String
  private var meta: String
  private var remain: String
  private var updated: String
  private var progress: Double
  private(set) var label = "내 다음 일정"

  public init(
    artist: String,
    meta: String,
    remain: String,
    updated: String,
    progress: Double
  ) {
    self.artist = artist
    self.meta = meta
    self.remain = remain
    self.updated = updated
    self.progress = progress
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      HStack {
        Text(label)
          .festiCoreFont(.baseFootnoteBold)
          .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
        Spacer()
        Text(updated)
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.staticalphaBlack60.color)
      }
      HStack(alignment: .bottom, spacing: FestiCoreSpacing.paddingP12) {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
          Text(artist)
            .festiCoreFont(.baseTitle1Bold)
            .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
          Text(meta)
            .festiCoreFont(.baseSubheadlineRegular)
            .foregroundStyle(FestiCoreSemanticColor.staticalphaBlack60.color)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        Text(remain)
          .festiCoreFont(.pointTitle)
          .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
      }
      Capsule()
        .fill(FestiCoreSemanticColor.staticalphaBlack20.color)
        .frame(height: 4)
        .overlay(alignment: .leading) {
          GeometryReader { proxy in
            Rectangle()
              .fill(FestiCoreSemanticColor.staticInk.color)
              .frame(width: proxy.size.width * min(max(progress, 0), 1))
          }
        }
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.staticLime.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r20))
    .accessibilityElement(children: .combine)
  }
}

// MARK: - 체이닝 설정

public extension FCNextSetCard {
  /// 위 라벨을 바꾼 사본을 돌려준다.
  func label(_ label: String) -> Self {
    var copy = self
    copy.label = label
    return copy
  }
}

/// 귀가 카드. 막차까지 남은 시간과 셔틀·막차 정보, 가는 길·같이 귀가 버튼을 보인다.
public struct FCHomeCard: View {
  private var remain: String
  private var shuttle: String
  private var train: String
  private var actions: [FCCardAction]
  private(set) var label = "귀가"

  public init(
    remain: String,
    shuttle: String,
    train: String,
    actions: [FCCardAction]
  ) {
    self.remain = remain
    self.shuttle = shuttle
    self.train = train
    self.actions = actions
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: .route16)
          .resizable()
          .frame(width: 16, height: 16)
          .accessibilityHidden(true)
        Text(label)
          .festiCoreFont(.baseFootnoteBold)
      }
      Text(remain)
        .festiCoreFont(.pointHeading)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(shuttle)
        Text(train)
      }
      .festiCoreFont(.baseCalloutMedium)
      FCCardActionRow(actions: actions)
    }
    .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.staticInk.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }
}

/// 하루 마무리 카드. 제목·부제와 통계 칸을 보인다.
public struct FCDoneCard: View {
  public struct Stat: Hashable, Sendable {
    public var value: String
    public var label: String

    public init(
      value: String,
      label: String
    ) {
      self.value = value
      self.label = label
    }
  }

  private var title: String
  private var sub: String
  private var stats: [Stat]

  public init(
    title: String,
    sub: String,
    stats: [Stat]
  ) {
    self.title = title
    self.sub = sub
    self.stats = stats
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(title)
          .festiCoreFont(.pointHeading)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(sub)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        ForEach(stats, id: \.self) { stat in
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
            Text(stat.value)
              .festiCoreFont(.baseTitle2Bold)
              .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            Text(stat.label)
              .festiCoreFont(.baseCaption1Regular)
              .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          }
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(FestiCoreSpacing.paddingP12)
          .background(FestiCoreSemanticColor.fillNormal.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
          .accessibilityElement(children: .combine)
        }
      }
    }
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }
}

/// 빈 상태 카드. 아이콘·제목·설명과 선택적 버튼을 보인다.
public struct FCEmptyCard: View {
  private var icon: ImageAsset
  private var title: String
  private var message: String
  private(set) var action: FCCardAction?

  public init(
    icon: ImageAsset = .users24,
    title: String,
    message: String
  ) {
    self.icon = icon
    self.title = title
    self.message = message
  }

  public var body: some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      Image(asset: icon)
        .resizable()
        .frame(width: 24, height: 24)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .frame(width: 48, height: 48)
        .background(FestiCoreSemanticColor.fillNormal.color, in: Circle())
        .accessibilityHidden(true)
      VStack(spacing: FestiCoreSpacing.paddingP4) {
        Text(title)
          .festiCoreFont(.baseBodyBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(message)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      .multilineTextAlignment(.center)
      if let action {
        FCButton(
          action.title,
          action: action.action
        )
        .style(action.style)
        .size(.medium)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }
}

// MARK: - 체이닝 설정

public extension FCEmptyCard {
  /// 아래 버튼을 바꾼 사본을 돌려준다. `nil`이면 버튼을 숨긴다.
  func action(_ action: FCCardAction?) -> Self {
    var copy = self
    copy.action = action
    return copy
  }
}

/// 가이드 한 단락. 제목·본문과 버튼 묶음을 보인다.
public struct FCGuideSection: View {
  private var title: String
  private var message: String
  private var actions: [FCCardAction]

  public init(
    title: String,
    message: String,
    actions: [FCCardAction] = []
  ) {
    self.title = title
    self.message = message
    self.actions = actions
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      Text(title)
        .festiCoreFont(.baseBodyBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text(message)
        .festiCoreFont(.baseCalloutRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      if !actions.isEmpty {
        FCCardActionRow(actions: actions)
          .padding(.top, FestiCoreSpacing.paddingP4)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }
}

#Preview {
  ScrollView {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
      FCNextSetCard(
        artist: "노이즈캔디",
        meta: "리벳 스테이지 · 15:40–16:30",
        remain: "12분 후",
        updated: "2분 전 업데이트",
        progress: 0.72
      )
      FCHomeCard(
        remain: "막차까지 52분",
        shuttle: "마지막 셔틀 23:40 · 정문 셔틀 정류장",
        train: "막차 23:52 · 서현역 (도보 12분)",
        actions: [
          FCCardAction(
            "가는 길",
            style: .accent
          ) {},
          FCCardAction("같이 귀가") {},
        ]
      )
      FCDoneCard(
        title: "오늘 수고했어요",
        sub: "원더리벳 2026 DAY 1 · 12:00–23:00",
        stats: [
          .init(
            value: "4",
            label: "본 공연"
          ),
          .init(
            value: "4명",
            label: "함께한 크루"
          ),
          .init(
            value: "2",
            label: "팔로우한 깃발"
          ),
        ]
      )
      FCEmptyCard(
        title: "아직 크루가 없어요",
        message: "친구를 초대하면 서로 어느 존에 있는지 바로 볼 수 있어요."
      )
      .action(FCCardAction(
        "크루 만들기",
        style: .primary
      ) {})
      FCGuideSection(
        title: "셔틀",
        message: "송도역 2번 출구 ↔ 행사장 입구 왼쪽 셔틀 존. 15분 간격으로 운행해요.",
        actions: [
          FCCardAction("셔틀 예약하기") {},
          FCCardAction("네이버 지도") {},
        ]
      )
    }
    .padding(FestiCoreSpacing.paddingP16)
  }
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
