import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI

/// Figma S08 크루 참여 확인(65-3705)
@ViewAction(for: FestivalCrewJoinFeature.self)
public struct FestivalCrewJoinView: View {
  @Bindable public var store: StoreOf<FestivalCrewJoinFeature>

  public init(store: StoreOf<FestivalCrewJoinFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      content
        .padding(
          .horizontal,
          Metric.horizontalPadding
        )
        .padding(
          .top,
          Metric.topPadding
        )
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(maxWidth: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color.ignoresSafeArea())
    .safeAreaInset(
      edge: .bottom,
      spacing: .zero
    ) {
      footer
    }
    .fcAlert($store.scope(
      state: \.alert,
      action: \.alert
    ))
    .task { send(.onAppear) }
  }
}

private extension FestivalCrewJoinView {
  @ViewBuilder
  var content: some View {
    switch store.load {
    case .loading:
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: Metric.skeletonHeight)
        .accessibilityLabel("초대를 불러오는 중")
    case .unavailable:
      FCEmptyCard(
        icon: .users24,
        title: "초대가 만료됐어요",
        message: "크루장에게 새 초대 링크를 받아 주세요."
      )
    case .failed:
      FCEmptyCard(
        title: "초대를 불러오지 못했어요",
        message: "연결을 확인한 뒤 다시 시도해 주세요."
      )
      .action(FCCardAction("다시 시도") { send(.retryTapped) })
    case .loaded:
      if let invite = store.invite {
        invitation(
          invite,
          blocker: store.state.blocker(now: .now)
        )
      }
    }
  }

  /// Figma S08 Contents: 간격 24, Hero 간격 12
  @ViewBuilder
  func invitation(
    _ invite: FestivalCrewInvite,
    blocker: FestivalCrewJoinFeature.Blocker?
  ) -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP24) {
      hero(
        invite,
        isBlocked: blocker != nil
      )
      if let blocker {
        inlineMessage(
          blocker,
          inviter: invite.inviterNickname
        )
      }
      detailCard(
        invite,
        isExpired: blocker == .expired
      )
      if blocker == nil {
        notice
      }
    }
  }

  func hero(
    _ invite: FestivalCrewInvite,
    isBlocked: Bool
  ) -> some View {
    return VStack(spacing: FestiCoreSpacing.marginM12) {
      Image(asset: .users24)
        .resizable()
        .frame(
          width: Metric.iconSize,
          height: Metric.iconSize
        )
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .frame(
          width: Metric.badgeSize,
          height: Metric.badgeSize
        )
        .background(
          FestiCoreSemanticColor.fillNormal.color,
          in: Circle()
        )
        .accessibilityHidden(true)
      Text(invite.inviterNickname.map { "\($0)님이 크루에 초대했어요" } ?? "크루에 초대받았어요")
        .festiCoreFont(.baseSubheadlineRegular)
        .festiCoreLineBox(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      // Figma S08 크루 이름: Point/Title. 참여할 수 없으면 Label/Assistive로 흐리게 둔다.
      Text(invite.crewName)
        .festiCoreFont(.pointTitle)
        .festiCoreLineBox(.pointTitle)
        .foregroundStyle(isBlocked
          ? FestiCoreSemanticColor.labelAssistive.color
          : FestiCoreSemanticColor.labelNormal.color)
        .multilineTextAlignment(.center)
    }
  }

  /// Figma S08 Inline Message: 아이콘 16 + 간격 6, Footnote/Regular · Status/Negative
  func inlineMessage(
    _ blocker: FestivalCrewJoinFeature.Blocker,
    inviter: String?
  ) -> some View {
    let text: String
    switch blocker {
    case .expired:
      text = "초대 링크가 만료됐어요 · \(inviter.map { "\($0)님" } ?? "크루장")에게 새 링크를 받아 주세요"
    case .full:
      text = "크루가 가득 찼어요 · 최대 \(FestivalCrew.maxMembers)명까지 들어갈 수 있어요"
    }
    return HStack(
      alignment: .top,
      spacing: Metric.inlineSpacing
    ) {
      Image(asset: .triangleExclamation16)
        .resizable()
        .frame(
          width: Metric.noticeIconSize,
          height: Metric.noticeIconSize
        )
        .padding(
          .top,
          Metric.inlineIconTop
        )
        .accessibilityHidden(true)
      Text(text)
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
    }
    .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
  }

  /// Figma S08 Info Card: 테두리 없이 Background/Elevated, 줄마다 위아래 16
  func detailCard(
    _ invite: FestivalCrewInvite,
    isExpired: Bool
  ) -> some View {
    let expiry = "\(invite.expiresAt.formatted(.festivalDay)) \(invite.expiresAt.formatted(.time))"
    return VStack(spacing: .zero) {
      detailRow(
        "페스티벌",
        value: invite.festivalName ?? "",
        showsDivider: true
      )
      detailRow(
        "인원",
        value: "\(invite.memberCount) / \(FestivalCrew.maxMembers)명",
        showsDivider: true
      )
      detailRow(
        "초대 만료",
        value: isExpired ? "\(expiry) · 만료" : expiry,
        showsDivider: false
      )
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .background(
      FestiCoreSemanticColor.backgroundElevated.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    )
  }

  func detailRow(
    _ title: String,
    value: String,
    showsDivider: Bool
  ) -> some View {
    return HStack(spacing: FestiCoreSpacing.paddingP8) {
      Text(title)
        .festiCoreFont(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      Spacer(minLength: FestiCoreSpacing.paddingP8)
      Text(value)
        .festiCoreFont(.baseSubheadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(1)
    }
    .frame(height: showsDivider ? Metric.rowHeight : Metric.lastRowHeight)
    .overlay(alignment: .bottom) {
      if showsDivider {
        Rectangle()
          .fill(FestiCoreSemanticColor.lineNormal.color)
          .frame(height: Metric.cardBorder)
      }
    }
  }

  var notice: some View {
    return HStack(
      alignment: .top,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Image(asset: .circleInfo16)
        .resizable()
        .frame(
          width: Metric.noticeIconSize,
          height: Metric.noticeIconSize
        )
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .accessibilityHidden(true)
      Text("참여하면 크루원에게 내 존과 상태가 보여요. 정확한 위치(GPS)는 공유하지 않아요.")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
    }
    // Figma S08 Notice: 사방 12, Fill/Strong
    .padding(FestiCoreSpacing.paddingP12)
    .background(
      FestiCoreSemanticColor.fillStrong.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    )
  }

  /// 참여할 수 없는 초대(S08 B·C)는 닫기 하나만 둔다.
  var footer: some View {
    return HStack(spacing: FestiCoreSpacing.paddingP8) {
      if store.load == .loaded, store.state.blocker(now: .now) != nil {
        FCButton("닫기") { send(.cancelTapped) }
          .isFullWidth(true)
      } else {
        FCButton("취소") { send(.cancelTapped) }
          .style(.ghost)
        FCButton(store.isJoining ? "참여하는 중" : "참여하기") { send(.joinTapped) }
          .isFullWidth(true)
          .isEnabled(store.load == .loaded && !store.isJoining)
      }
    }
    .padding(
      .top,
      Metric.footerTopPadding
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .bottom,
      Metric.footerBottomPadding
    )
    .background(FestiCoreSemanticColor.backgroundElevated.color.ignoresSafeArea(edges: .bottom))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(FestiCoreSemanticColor.lineNormal.color)
        .frame(height: Metric.cardBorder)
    }
  }

  enum Metric {
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 40
    static let badgeSize: CGFloat = 72
    static let iconSize: CGFloat = 24
    static let rowHeight: CGFloat = 55
    static let lastRowHeight: CGFloat = 54
    static let inlineSpacing: CGFloat = 6
    static let inlineIconTop: CGFloat = 1
    static let cardBorder: CGFloat = 1
    static let noticeIconSize: CGFloat = 16
    static let skeletonHeight: CGFloat = 154
    static let footerTopPadding: CGFloat = 13
    static let footerBottomPadding: CGFloat = 1
  }
}
