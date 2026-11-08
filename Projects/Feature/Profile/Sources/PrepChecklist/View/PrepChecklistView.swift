//
//  PrepChecklistView.swift
//  Profile
//
//  Created by FestiCore on 11/9/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestivalDomainInterface
import SwiftUI

/// Figma S15-③ 준비 안내 · 준비물. 구성은 내 일정 고르기(S15-①)와 같다.
@ViewAction(for: PrepChecklistFeature.self)
public struct PrepChecklistView: View {
  @Bindable public var store: StoreOf<PrepChecklistFeature>

  public init(store: StoreOf<PrepChecklistFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCStepHeader(step: 3)
        .onLater { send(.laterTapped) }
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.paddingP20
        ) {
          header
          content
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollIndicators(.hidden)
      bottomBar
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .onAppear { send(.onAppear) }
  }
}

private extension PrepChecklistView {
  var header: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text("Step 3. 준비물 챙기기")
        .festiCoreFont(.baseCaption1Medium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      Text("준비물 체크리스트를 미리 챙겨 볼까요?")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text("D-1 저녁에 한 번 더 알려 드려요.")
        .festiCoreFont(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  @ViewBuilder
  var content: some View {
    switch store.detail.load {
    case .loading:
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: Metric.skeletonHeight)
        .accessibilityLabel("준비물을 불러오는 중")
    case .loaded:
      checklist
    case .missing, .failed:
      FCEmptyCard(
        title: "준비물을 불러오지 못했어요",
        message: "건너뛰고 나중에 마이 > 받은 팩에서 챙길 수 있어요."
      )
    }
  }

  var checklist: some View {
    let rows = store.detail.checklistRows
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text("\(rows.count)개 중 \(store.detail.checkedCount)개 챙겼어요")
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .frame(
          maxWidth: .infinity,
          alignment: .trailing
        )
      if let rules = store.detail.detail?.rules, !rules.isEmpty {
        rulesCard(rules)
      }
      VStack(spacing: .zero) {
        ForEach(rows) { row in
          FCChecklistRow(
            row.label,
            isChecked: row.isChecked
          ) {
            send(.itemToggled(row.id))
          }
          .isRequired(row.isRequired)
          divider
        }
        FCAddItemRow(
          text: Binding(
            get: { store.detail.newItemText },
            set: { send(.newItemTextChanged($0)) }
          )
        ) {
          send(.addItemTapped)
        }
      }
      // 시안 Checklist 카드는 화면과 같은 바탕(#1C1C20)이라 줄 사이 구분선만 보인다.
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }

  /// 반입 금지 안내(시안 Carry-in Rules: 주황 10% 바탕)
  func rulesCard(_ rules: [String]) -> some View {
    return VStack(
      alignment: .leading,
      spacing: Metric.rulesSpacing
    ) {
      HStack(spacing: Metric.rulesSpacing) {
        Image(asset: .triangleExclamation16)
          .resizable()
          .frame(
            width: Metric.iconSize,
            height: Metric.iconSize
          )
          .foregroundStyle(FestiCoreSemanticColor.accentPointOrange.color)
          .accessibilityHidden(true)
        Text("반입 금지 · \(store.detail.title)")
          .festiCoreFont(.baseFootnoteBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      }
      Text(rules.joined(separator: " · "))
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP12
    )
    .background(
      FestiCoreSemanticColor.accentPointOrange.color.opacity(Metric.rulesOpacity),
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    )
  }

  var divider: some View {
    return FestiCoreSemanticColor.lineNormal.color
      .frame(height: Metric.divider)
      .padding(
        .leading,
        FestiCoreSpacing.paddingP16
      )
  }

  var bottomBar: some View {
    return HStack(spacing: FestiCoreSpacing.paddingP8) {
      FCButton("건너뛰기") { send(.skipTapped) }
        .style(.ghost)
      FCButton("준비 완료") { send(.doneTapped) }
        .isFullWidth(true)
    }
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

  enum Metric {
    static let skeletonHeight: CGFloat = 320
    static let rulesSpacing: CGFloat = 6
    static let iconSize: CGFloat = 16
    static let rulesOpacity: Double = 0.1
    static let divider: CGFloat = 1
  }
}
