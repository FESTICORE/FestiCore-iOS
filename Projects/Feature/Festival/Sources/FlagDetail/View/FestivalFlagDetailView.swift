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

/// Figma S05 깃발 상세. 공유·잠금화면 표시·신고하기를 포함한다.
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
    .fcModal($store.scope(
      state: \.destination?.report,
      action: \.destination.report
    )) { reportStore in
      FestivalFlagReportView(store: reportStore)
    }
    .onAppear { send(.onAppear) }
    .onDisappear { send(.onDisappear) }
  }
}

private extension FestivalFlagDetailView {
  enum Metric {
    static let planListVerticalPadding = FestiCoreSpacing.paddingP4
    /// 지금 카드와 잠금화면 표시 카드 사이(시안 B 실측)
    static let nowSectionSpacing = FestiCoreSpacing.paddingP20
  }

  /// 뒤로 가기·깃발 이름·공유. 상세를 받기 전에는 공유를 감춘다.
  @ViewBuilder
  var topBar: some View {
    let bar = FCTopBar(
      .back,
      title: store.detail?.name ?? ""
    )
    .onBack { send(.backTapped) }

    if let detail = store.detail {
      bar.shareLink(
        store.shareURL,
        title: detail.name
      )
    } else {
      bar
    }
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
          VStack(spacing: Metric.nowSectionSpacing) {
            nowCard()

            lockScreenRow()
          }

          planSection(detail)

          reportButton
        }
        .padding(
          .top,
          FestiCoreSpacing.paddingP20
        )
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP16
        )
      }
    }
    .fcScrollBottomInset()
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

  /// 팔로우 중인 깃발만 잠금화면 대표 깃발로 켜고 끈다.
  @ViewBuilder
  func lockScreenRow() -> some View {
    if store.showsLockScreenToggle {
      FCListRow(
        "잠금화면에 표시",
        isOn: Binding(
          get: { store.isPinned },
          set: { send(.lockScreenToggled($0)) }
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }

  /// 계획 아래 가운데 신고 버튼. 누르면 사유 선택 시트를 띄운다.
  var reportButton: some View {
    return Button { send(.reportTapped) } label: {
      Text("신고하기")
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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

  /// 팔로우·신고·잠금화면 표시 결과 안내
  @ViewBuilder
  func toast() -> some View {
    if let toast = store.toast {
      FCToast(toastItem(toast))
        .iconColor(toastIconColor(toast))
        .padding(FestiCoreSpacing.paddingP16)
        .transition(.opacity)
    }
  }

  func toastItem(_ toast: FestivalFlagDetailFeature.State.Toast) -> FCToast.Item {
    switch toast {
    case let .followed(name): return .followed(name)
    case .followLimit: return info("팔로우는 100개까지 할 수 있어요")
    case .followFailed: return info("팔로우를 바꾸지 못했어요. 잠시 후 다시 시도해 주세요")
    case .reported: return FCToast.Item(
      icon: .check,
      message: "신고를 접수했어요"
    )
    case .alreadyReported: return info("이미 신고한 깃발이에요")
    case .reportFailed: return info("신고하지 못했어요. 잠시 후 다시 시도해 주세요")
    case .pinFailed: return info("잠금화면 표시를 바꾸지 못했어요")
    }
  }

  /// 팔로우 완료만 깃발 아이콘을 라임으로 강조한다(시안 A→B).
  func toastIconColor(_ toast: FestivalFlagDetailFeature.State.Toast) -> Color {
    guard case .followed = toast else { return FestiCoreSemanticColor.staticWhite.color }
    return FestiCoreSemanticColor.staticLime.color
  }

  func info(_ message: String) -> FCToast.Item {
    return FCToast.Item(
      icon: .circleInfo16,
      message: message
    )
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
