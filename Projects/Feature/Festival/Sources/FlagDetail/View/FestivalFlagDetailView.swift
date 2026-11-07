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
  public let store: StoreOf<FestivalFlagDetailFeature>

  public init(store: StoreOf<FestivalFlagDetailFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .back,
        title: store.detail?.name ?? ""
      )
      .onBack { send(.backTapped) }
      if let offlineText = store.offlineText {
        FCOfflineBadge(offlineText)
      }
      content
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .overlay(alignment: .bottom) { toast }
    .onAppear { send(.onAppear) }
    .onDisappear { send(.onDisappear) }
  }
}

private extension FestivalFlagDetailView {
  @ViewBuilder
  var content: some View {
    switch store.content {
    case .loading:
      loadingContent
    case .failed(.notFound):
      FCEmptyCard(
        title: "깃발을 찾을 수 없어요",
        message: "숨겨졌거나 더 이상 공개하지 않는 깃발이에요."
      )
      .padding(FestiCoreSpacing.paddingP16)
      .frame(
        maxHeight: .infinity,
        alignment: .top
      )
    case .failed(.unavailable):
      failedContent
    case let .loaded(detail):
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: .zero
        ) {
          hero(detail)
          VStack(
            alignment: .leading,
            spacing: FestiCoreSpacing.paddingP24
          ) {
            nowCard
            planSection(detail)
          }
          .padding(FestiCoreSpacing.paddingP16)
        }
      }
    }
  }

  var loadingContent: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      FCSkeletonView(.round())
        .frame(height: Metric.heroHeight)
      FCSkeletonView(.round())
        .frame(height: Metric.skeletonCardHeight)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP16
        )
      Spacer(minLength: .zero)
    }
  }

  var failedContent: some View {
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

  func hero(_ detail: FestivalFlagDetail) -> some View {
    return FCFlagHero(
      name: detail.name,
      followers: "팔로워 \(store.followerCount.formatted())",
      tags: detail.tags.map(tagTitle),
      status: chipStatus(detail.status),
      intro: detail.bio.map { "“\($0)”" } ?? "",
      isFollowing: store.isFollowing,
      onFollow: { send(.followTapped) }
    ) {
      if let url = detail.photoURL ?? detail.thumbnailURL {
        FCRemoteImage(url: url)
          .content(.fill)
      } else {
        FestiCoreSemanticColor.backgroundElevated.color
      }
    }
    .disabled(store.isOffline || store.isFollowPending)
  }

  @ViewBuilder
  var nowCard: some View {
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

  @ViewBuilder
  func planSection(_ detail: FestivalFlagDetail) -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP12
    ) {
      HStack {
        Text("오늘 계획")
          .festiCoreFont(.baseHeadlineBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Spacer(minLength: FestiCoreSpacing.paddingP8)
        if detail.isPlanVisible {
          Text("기수가 정한 순서예요")
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
      }
      if !detail.isPlanVisible {
        FCPlanPrivate()
      } else if store.planRows.isEmpty {
        FCPlanPrivate(
          title: "오늘 계획이 아직 없어요",
          message: "기수가 계획을 올리면 여기에서 볼 수 있어요"
        )
      } else {
        planList
      }
    }
  }

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
      FestiCoreSpacing.paddingP8
    )
    .background(
      FestiCoreSemanticColor.backgroundElevated.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    )
  }

  @ViewBuilder
  var toast: some View {
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

  func tagTitle(_ tag: String) -> String {
    return FestivalFlagDirectory.Tag(rawValue: tag)?.title ?? tag
  }

  enum Metric {
    static let heroHeight: CGFloat = 360
    static let skeletonCardHeight: CGFloat = 104
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
