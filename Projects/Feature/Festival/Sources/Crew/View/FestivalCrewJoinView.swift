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
        invitation(invite)
      }
    }
  }

  @ViewBuilder
  func invitation(_ invite: FestivalCrewInvite) -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
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
        .festiCoreFont(.baseFootnoteMedium)
        .festiCoreLineBox(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      Text(invite.crewName)
        .festiCoreFont(.baseLargeTitleBold)
        .festiCoreLineBox(.baseLargeTitleBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .multilineTextAlignment(.center)
      detailCard(invite)
      notice
    }
  }

  func detailCard(_ invite: FestivalCrewInvite) -> some View {
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
        value: "\(invite.expiresAt.formatted(.festivalDay)) \(invite.expiresAt.formatted(.time))",
        showsDivider: false
      )
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .vertical,
      Metric.cardBorder
    )
    .background(
      FestiCoreSemanticColor.backgroundElevated.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    )
    .overlay {
      RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        .strokeBorder(
          FestiCoreSemanticColor.lineNormal.color,
          lineWidth: Metric.cardBorder
        )
    }
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
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP12
    )
    .background(
      FestiCoreSemanticColor.fillNormal.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    )
  }

  var footer: some View {
    return HStack(spacing: FestiCoreSpacing.paddingP8) {
      FCButton("취소") { send(.cancelTapped) }
        .style(.ghost)
      FCButton(store.isJoining ? "참여하는 중" : "참여하기") { send(.joinTapped) }
        .isFullWidth(true)
        .isEnabled(store.load == .loaded && !store.isJoining)
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
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 48
    static let badgeSize: CGFloat = 72
    static let iconSize: CGFloat = 24
    static let rowHeight: CGFloat = 51
    static let lastRowHeight: CGFloat = 50
    static let cardBorder: CGFloat = 1
    static let noticeIconSize: CGFloat = 16
    static let skeletonHeight: CGFloat = 154
    static let footerTopPadding: CGFloat = 13
    static let footerBottomPadding: CGFloat = 1
  }
}
