//
//  FCInfoCards.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 계획 비공개 안내 카드.
public struct FCPlanPrivate: View {
  private var title: String
  private var message: String

  public init(
    title: String = "오늘 계획은 비공개예요",
    message: String = "기수가 계획을 공개하면 여기에서 볼 수 있어요"
  ) {
    self.title = title
    self.message = message
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      Image(asset: .circleInfo20)
        .resizable()
        .frame(width: 20, height: 20)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM2) {
        Text(title)
          .festiCoreFont(.baseCalloutMedium)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        Text(message)
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, FestiCoreSpacing.paddingP20)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    .accessibilityElement(children: .combine)
  }
}

/// 개장·공연까지 남은 시간 카드.
public struct FCCountdownCard: View {
  private var label: String
  private var time: String
  private var sub: String

  public init(
    label: String,
    time: String,
    sub: String
  ) {
    self.label = label
    self.time = time
    self.sub = sub
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      Text(label)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      Text(time)
        .festiCoreFont(.pointTitle)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text(sub)
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(FestiCoreSpacing.paddingP20)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    .accessibilityElement(children: .combine)
  }
}

/// 마지막 셔틀·막차 시간 카드.
public struct FCLastRideCard: View {
  private var shuttle: String
  private var train: String

  public init(
    shuttle: String,
    train: String
  ) {
    self.shuttle = shuttle
    self.train = train
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP16) {
      column(
        "마지막 셔틀",
        time: shuttle
      )
      FestiCoreSemanticColor.lineNormal.color
        .frame(width: 1)
      column(
        "막차",
        time: train
      )
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }

}

private extension FCLastRideCard {
  func column(
    _ label: String,
    time: String
  ) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM2) {
      Text(label)
        .festiCoreFont(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      Text(time)
        .festiCoreFont(.baseTitle1Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// 깃발 상세 상단 기수 헤더. 이름·상태·팔로워 수를 보인다.
public struct FCBearerHeader: View {
  private var name: String
  private var status: FCStatusChip.Status
  private var statusText: String
  private var followers: String

  public init(
    name: String,
    status: FCStatusChip.Status,
    statusText: String,
    followers: String
  ) {
    self.name = name
    self.status = status
    self.statusText = statusText
    self.followers = followers
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      Text(name)
        .festiCoreFont(.baseTitle1Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        FCStatusChip(status)
        Text(statusText)
          .festiCoreFont(.baseCalloutRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Text(followers)
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
    .padding(.top, FestiCoreSpacing.paddingP16)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .padding(.bottom, FestiCoreSpacing.paddingP8)
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCPlanPrivate()
    FCCountdownCard(
      label: "개장까지",
      time: "2시간 14분",
      sub: "12:00 개장 · 첫 공연 13:00 리벳 스테이지"
    )
    FCLastRideCard(
      shuttle: "23:40",
      train: "23:52"
    )
    FCBearerHeader(
      name: "호락호락",
      status: .active,
      statusText: "리벳 스테이지 앞 왼쪽 · 슬램 · 4분 전",
      followers: "팔로워 1,284명이 보고 있어요"
    )
  }
  .padding(FestiCoreSpacing.paddingP16)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
