//
//  BearerFestivalTransferView.swift
//  Bearer
//
//  Created by FestiCore on 11/26/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// 깃발 상세 메뉴의 '다른 페스티벌로 옮기기'. 이동 전용 시안이 없어 S14 D 등록 화면의 페스티벌 목록·하단 버튼 스타일을 그대로 쓴다.
@ViewAction(for: BearerFestivalTransferFeature.self)
public struct BearerFestivalTransferView: View {
  @Bindable public var store: StoreOf<BearerFestivalTransferFeature>

  public init(store: StoreOf<BearerFestivalTransferFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .back,
        title: "다른 페스티벌로 옮기기"
      )
      .onBack { send(.backTapped) }
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: Metric.groupSpacing
        ) {
          helper("고른 페스티벌로 깃발을 옮겨요. 이름·사진·팔로워는 그대로이고 계획·주로 있는 존·현장 상태는 초기화돼요.")
          festivalSection
          if let errorMessage = store.errorMessage {
            Text(errorMessage)
              .festiCoreFont(.baseFootnoteRegular)
              .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .safeAreaInset(
        edge: .bottom,
        spacing: .zero
      ) {
        actionBar
      }
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .fcAlert($store.scope(
      state: \.destination?.confirm,
      action: \.destination.confirm
    ))
    .onAppear { send(.onAppear) }
  }
}

private extension BearerFestivalTransferView {
  enum Metric {
    /// 등록 화면 페스티벌 목록과 같은 간격(Figma S14 D)
    static let groupSpacing: CGFloat = 12
    static let rowHeight: CGFloat = 44
  }

  @ViewBuilder
  var festivalSection: some View {
    switch store.festivals.load {
    case .loading:
      ForEach(0 ..< BearerRegisterFeature.upcomingPreviewCount, id: \.self) { _ in
        FCSkeletonView(.round()).frame(height: Metric.rowHeight)
      }

    case let .failed(offline):
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP8
      ) {
        helper(offline
          ? "인터넷에 연결되지 않아 페스티벌을 불러오지 못했어요."
          : "옮길 수 있는 다른 페스티벌이 없어요.")
        FCButton("다시 시도") { send(.retryTapped) }
          .style(.secondary)
          .size(.medium)
      }

    case .loaded:
      festivalRows
    }
  }

  @ViewBuilder
  var festivalRows: some View {
    if !store.festivals.received.isEmpty {
      helper("내가 받은 팩")
      ForEach(store.festivals.received) { option in
        festivalButton(option)
      }
      if !store.festivals.visibleUpcoming.isEmpty {
        helper("다른 페스티벌")
      }
    }
    ForEach(store.festivals.visibleUpcoming) { option in
      festivalButton(option)
    }
    if store.festivals.canShowMore {
      FCButton("다른 페스티벌 찾기") { send(.showMoreTapped) }
        .style(.ghost)
        .frame(maxWidth: .infinity)
    }
  }

  func festivalButton(_ option: BearerFestivalOption) -> some View {
    return BearerZoneButton(
      name: option.title,
      isSelected: store.selectedFestivalID == option.id
    ) {
      send(.festivalTapped(option.id))
    }
  }

  /// Figma S10·S14 Bottom Bar: 글래스 배경, 위 12·아래 8
  var actionBar: some View {
    return FCPrimaryButton(
      store.isSaving ? "옮기는 중이에요" : "이 페스티벌로 옮기기",
      isEnabled: store.canTransfer
    ) {
      send(.transferTapped)
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
    .background {
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay(FestiCoreSemanticColor.materialGlass.color)
        .ignoresSafeArea(edges: .bottom)
    }
  }

  func helper(_ text: String) -> some View {
    return Text(text)
      .festiCoreFont(.baseFootnoteRegular)
      .festiCoreLineBox(.baseFootnoteRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }
}

#Preview {
  BearerFestivalTransferView(store: .init(initialState: BearerFestivalTransferFeature.State(
    flagID: "flg_1",
    fromFestivalID: "fst_wonder"
  )) {
    BearerFestivalTransferFeature()
  })
}
