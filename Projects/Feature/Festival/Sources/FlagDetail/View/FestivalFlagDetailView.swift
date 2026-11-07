//
//  FestivalFlagDetailView.swift
//  Festival
//
//  Created by FestiCore on 11/7/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

/// Figma S05 깃발 상세. 공유·신고는 다음 단계에서 붙인다.
@ViewAction(for: FestivalFlagDetailFeature.self)
public struct FestivalFlagDetailView: View {
  @Bindable public var store: StoreOf<FestivalFlagDetailFeature>

  public init(store: StoreOf<FestivalFlagDetailFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      topBar

      if let offlineText = store.offlineText {
        FCOfflineBadge(offlineText)
      }

      content()
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .overlay(alignment: .bottom) {
      toast()
    }
    .onAppear { send(.onAppear) }
    .onDisappear { send(.onDisappear) }
  }
}

private extension FestivalFlagDetailView {
  enum Metric {
    static let planListVerticalPadding = FestiCoreSpacing.paddingP4
  }

  /// 뒤로 가기와 깃발 이름
  var topBar: some View {
    return FCTopBar(
      .back,
      title: store.detail?.name ?? ""
    )
    .onBack { send(.backTapped) }
  }

  /// 불러오는 중·없는 깃발·일시 오류·상세 본문
  @ViewBuilder
  func content() -> some View {
    switch store.content {
    case .loading:
      FestivalFlagDetailSkeletonView()

    case .failed(.notFound):
      notFoundContent

    case .failed(.unavailable):
      retryContent

    case let .loaded(detail):
      loadedContent(detail)
    }
  }

  /// 사진 히어로 아래에 지금 카드와 오늘 계획을 쌓는다.
  func loadedContent(_ detail: FestivalFlagDetail) -> some View {
    return ScrollView {
      VStack(
        alignment: .leading,
        spacing: .zero
      ) {
        hero(detail)

        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.paddingP24
        ) {
          nowCard()

          planSection(detail)
        }
        .padding(
          .top,
          FestiCoreSpacing.paddingP20
        )
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP16
        )
        .padding(
          .bottom,
          FestiCoreSpacing.paddingP16
        )
      }
    }
  }

  /// 숨겨졌거나 공개하지 않는 깃발
  var notFoundContent: some View {
    return FCEmptyCard(
      title: "깃발을 찾을 수 없어요",
      message: "숨겨졌거나 더 이상 공개하지 않는 깃발이에요."
    )
    .padding(FestiCoreSpacing.paddingP16)
    .frame(
      maxHeight: .infinity,
      alignment: .top
    )
  }

  /// 첫 조회가 실패했을 때 다시 시도
  var retryContent: some View {
    return VStack(spacing: FestiCoreSpacing.paddingP12) {
      Text("깃발 정보를 불러오지 못했어요")
        .festiCoreFont(.baseBodyMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)

      FCButton("다시 시도") { send(.retryTapped) }
        .style(.secondary)
        .size(.medium)
    }
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity
    )
  }

  /// 사진 위 이름·팔로워·태그·팔로우 버튼·소개와 상태 칩
  func hero(_ detail: FestivalFlagDetail) -> some View {
    return FCFlagHero(
      name: detail.name,
      followers: "팔로워 \(store.followerCount.formatted())",
      tags: store.tagTitles,
      status: chipStatus(detail.status),
      intro: detail.bio.map { "“\($0)”" } ?? "",
      isFollowing: store.isFollowing,
      onFollow: { send(.followTapped) }
    ) {
      heroBackground(detail)
    }
    // 오프라인이거나 요청 중이면 팔로우 버튼만 끈다.
    .followEnabled(!store.isOffline && !store.isFollowPending)
  }

  /// 깃발 사진. 없으면 카드 배경색으로 채운다.
  @ViewBuilder
  func heroBackground(_ detail: FestivalFlagDetail) -> some View {
    if let url = detail.photoURL ?? detail.thumbnailURL {
      FCRemoteImage(url: url)
        .content(.fill)
    } else {
      FestiCoreSemanticColor.backgroundElevated.color
    }
  }

  /// 지금 위치·활동 또는 오늘 활동 종료
  @ViewBuilder
  func nowCard() -> some View {
    switch store.nowCard {
    case let .located(
      zone,
      activity,
      source,
      isMuted
    ):
      if isMuted {
        FCFlagNowCard(.muted(
          zone: zone,
          activity: activity,
          source: source
        ))
      } else {
        FCFlagNowCard(.active(
          zone: zone,
          activity: activity,
          source: source
        ))
      }

    case .ended:
      FCFlagNowCard(.ended())

    case nil:
      EmptyView()
    }
  }

  /// "오늘 계획" 머리글과 계획 목록 또는 비공개 안내
  @ViewBuilder
  func planSection(_ detail: FestivalFlagDetail) -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP12
    ) {
      planHeader(isVisible: detail.isPlanVisible)

      if !detail.isPlanVisible {
        FCPlanPrivate()
      } else if detail.planSetIDs.isEmpty {
        FCPlanPrivate(
          title: "오늘 계획이 아직 없어요",
          message: "기수가 계획을 올리면 여기에서 볼 수 있어요"
        )
      } else if store.planRows.isEmpty {
        // 공개한 계획이 있지만 받은 팩에서 공연을 찾지 못했다.
        FCPlanPrivate(
          title: "공연 정보를 아직 받지 못했어요",
          message: "축제 팩을 받으면 계획을 볼 수 있어요"
        )
      } else {
        planList
      }
    }
  }

  /// 공개한 계획에만 "기수가 정한 순서예요"를 붙인다.
  func planHeader(isVisible: Bool) -> some View {
    return HStack {
      Text("오늘 계획")
        .festiCoreFont(.baseHeadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)

      Spacer(minLength: FestiCoreSpacing.paddingP8)

      if isVisible {
        Text("기수가 정한 순서예요")
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
    }
  }

  /// 기수가 정한 순서대로 공연을 보인다.
  var planList: some View {
    return VStack(spacing: .zero) {
      ForEach(store.planRows) { row in
        FCPlanRow(
          time: row.time,
          artist: row.artist,
          stage: row.stage,
          state: planState(row.timing)
        )
        .isMine(row.isMine)
      }
    }
    .padding(
      .vertical,
      Metric.planListVerticalPadding
    )
    .background(
      FestiCoreSemanticColor.backgroundElevated.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    )
  }

  /// 팔로우 실패 안내
  @ViewBuilder
  func toast() -> some View {
    if let message = store.toast {
      FCToast(.init(
        icon: .circleInfo16,
        message: message
      ))
      .padding(FestiCoreSpacing.paddingP16)
      .transition(.opacity)
    }
  }

  func chipStatus(_ status: FestivalFlagDetail.Status) -> FCStatusChip.Status {
    switch status {
    case .active: return .active
    case .resting: return .resting
    case .scheduled: return .scheduled
    case .ended: return .endedToday
    }
  }

  func planState(_ timing: FestivalFlagDetailPlanRow.Timing) -> FCPlanRow.State {
    switch timing {
    case .upcoming: return .upcoming
    case .now: return .now
    case .past: return .past
    }
  }
}

#Preview {
  FestivalFlagDetailView(store: Store(initialState: FestivalFlagDetailFeature.State(
    flagID: "flg_preview",
    context: FestivalFlagDetailContext()
  )) {
    FestivalFlagDetailFeature()
  })
  .preferredColorScheme(.dark)
}
