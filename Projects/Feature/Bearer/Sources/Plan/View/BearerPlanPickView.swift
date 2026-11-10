//
//  BearerPlanPickView.swift
//  Bearer
//
//  Created by FestiCore on 11/8/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreUtility
import SwiftUI

/// 깃발 프로필의 '오늘 계획' 고르기. 내 일정 고르기(S15-1)와 같은 구성으로 그린다.
@ViewAction(for: BearerPlanPickFeature.self)
public struct BearerPlanPickView: View {
  public let store: StoreOf<BearerPlanPickFeature>

  public init(store: StoreOf<BearerPlanPickFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .back,
        title: "오늘 계획"
      )
      .onBack { send(.backTapped) }
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.paddingP20
        ) {
          header
          if store.days.isEmpty {
            emptyMessage
          } else {
            FCSegmented(
              selection: dayBinding,
              items: store.days.map(\.title)
            )
            setList
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      bottomBar
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
  }
}

private extension BearerPlanPickView {
  var header: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text("오늘 갈 무대를 골라 주세요")
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text("고른 무대는 깃발의 오늘 계획으로 보여요.\n깃발 프로필을 저장하면 반영돼요.")
        .festiCoreFont(.baseSubheadlineRegular)
        .festiCoreLineBox(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  var emptyMessage: some View {
    return Text("받아 둔 팩에 공연 시간이 아직 없어요.")
      .festiCoreFont(.baseSubheadlineRegular)
      .festiCoreLineBox(.baseSubheadlineRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      .frame(
        maxWidth: .infinity,
        alignment: .center
      )
      .padding(
        .vertical,
        FestiCoreSpacing.paddingP24
      )
  }

  var setList: some View {
    return VStack(
      alignment: .trailing,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text("\(store.selectedSetIDs.count)개 선택")
        .festiCoreFont(.baseFootnoteBold)
        .festiCoreLineBox(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      if let day = store.selectedDay {
        VStack(spacing: .zero) {
          ForEach(
            Array(day.sets.enumerated()),
            id: \.element.id
          ) { index, set in
            if index > 0 {
              FestiCoreSemanticColor.lineNormal.color.frame(height: Metric.divider)
            }
            setRow(set)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
        .overlay(
          RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
            .stroke(
              FestiCoreSemanticColor.lineNormal.color,
              lineWidth: Metric.divider
            )
        )
      }
      if let message = store.limitMessage {
        Text(message)
          .festiCoreFont(.baseCaption1Regular)
          .festiCoreLineBox(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )
      }
    }
  }

  func setRow(_ set: BearerSet) -> some View {
    return FCSetSelectRow(
      artist: set.artist,
      stage: set.stageName ?? "무대 미정",
      start: set.startsAt.formatted(.time),
      end: set.endsAt.formatted(.time),
      isSelected: store.selectedSetIDs.contains(set.id)
    ) {
      send(.setTapped(set.id))
    }
  }

  var bottomBar: some View {
    return FCButton("\(store.selectedSetIDs.count)개 선택 완료") { send(.doneTapped) }
      .isFullWidth(true)
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )
      .padding(
        .top,
        FestiCoreSpacing.paddingP12
      )
      .padding(
        .bottom,
        FestiCoreSpacing.paddingP8
      )
      .overlay(alignment: .top) {
        FestiCoreSemanticColor.lineNormal.color.frame(height: Metric.divider)
      }
      .background(FestiCoreSemanticColor.backgroundElevated.color)
  }

  var dayBinding: Binding<Int> {
    return Binding(
      get: { store.selectedDayIndex },
      set: { send(.dayTapped($0)) }
    )
  }

  enum Metric {
    static let divider: CGFloat = 1
  }
}
