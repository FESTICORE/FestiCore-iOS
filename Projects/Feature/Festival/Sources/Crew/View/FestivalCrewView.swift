import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

/// Figma S07 크루(65-3675·65-4010)와 모여! 쿨다운(65-3976)
@ViewAction(for: FestivalCrewFeature.self)
public struct FestivalCrewView: View {
  @Bindable public var store: StoreOf<FestivalCrewFeature>

  public init(store: StoreOf<FestivalCrewFeature>) {
    self.store = store
  }

  public var body: some View {
    TimelineView(.periodic(
      from: .now,
      by: Metric.refreshInterval
    )) { context in
      let presentation = FestivalCrewPresentation(
        crew: store.state,
        now: context.date
      )
      VStack(spacing: .zero) {
        topBar
        content(presentation)
      }
      .background(FestiCoreSemanticColor.backgroundNormal.color.ignoresSafeArea())
      .safeAreaInset(
        edge: .bottom,
        spacing: .zero
      ) {
        if !presentation.isArchived {
          statusPanel
        }
      }
    }
    .overlay(alignment: .top) { toast }
    .animation(
      .easeOut(duration: Metric.toastAnimation),
      value: store.toast
    )
    .fcModal($store.scope(
      state: \.destination?.gather,
      action: \.destination.gather
    )) { gatherStore in
      FestivalCrewGatherView(store: gatherStore)
    }
    .fcModal($store.scope(
      state: \.destination?.menu,
      action: \.destination.menu
    )) { menuStore in
      FestivalCrewMenuView(store: menuStore)
    }
    .fcAlert($store.scope(
      state: \.destination?.alert,
      action: \.destination.alert
    ))
    .fcAlert($store.scope(
      state: \.destination?.confirm,
      action: \.destination.confirm
    ))
    .task { send(.onAppear) }
  }
}

private extension FestivalCrewView {
  var topBar: some View {
    let bar = FCTopBar(
      .back,
      title: store.title
    )
    .onBack { send(.backTapped) }
    .backgroundColor(.backgroundNavigation)
    guard store.isLeader else { return bar }
    // Figma S07 A: Top Bar 오른쪽 Action은 gear 24(Label/Neutral)다.
    return bar.trailingAction(
      icon: .gear24,
      accessibilityLabel: "크루장 메뉴"
    ) { send(.menuTapped) }
  }

  @ViewBuilder
  func content(_ presentation: FestivalCrewPresentation) -> some View {
    ScrollView {
      // Figma S07 Contents: 간격 16
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP16
      ) {
        if presentation.isArchived {
          // Figma S07 I: 끝난 크루는 안내 띠와 기록만 둔다.
          FCBanner(archivedNotice) {}
            .icon(.circleInfo16)
            .showsChevron(false)
            .allowsHitTesting(false)
          summaryText(presentation)
        } else {
          // Figma S07 F: 받은 모여 요청은 화면 맨 위 라임 배너로 띄운다.
          if let gather = presentation.gather {
            gatherBanner(gather)
          }
          summaryRow(presentation)
          FCButton(presentation.gatherTitle) { send(.gatherTapped) }
            .isFullWidth(true)
            .isEnabled(presentation.canGather)
        }
        members(presentation)
      }
      .padding(FestiCoreSpacing.paddingP16)
    }
    .scrollBounceBehavior(.basedOnSize)
  }

  /// Figma S07 I Banner: "원더리벳 2026이 끝났어요 · 기록만 볼 수 있어요"
  var archivedNotice: String {
    let festival = store.festivalName.map { "\($0.withIGa) " } ?? "페스티벌이 "
    return "\(festival)끝났어요 · 기록만 볼 수 있어요"
  }

  /// Figma S07 F Gather Banner: Static/Lime, 사방 16, 간격 12, 모서리 16
  func gatherBanner(_ gather: FestivalCrewPresentation.Gather) -> some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM12
    ) {
      // Figma S07 F Top: users 20 + 간격 8, Headline/Bold · Static/Ink
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: .users24)
          .resizable()
          .frame(
            width: Metric.gatherIconSize,
            height: Metric.gatherIconSize
          )
          .accessibilityHidden(true)
        Text(gather.title)
          .festiCoreFont(.baseHeadlineBold)
          .festiCoreLineBox(.baseHeadlineBold)
          .lineLimit(1)
      }
      .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
      Text(gather.detail)
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.staticalphaBlack60.color)
      if let actions = gather.actions {
        gatherActions(actions)
      } else if let summary = gather.summary {
        gatherPill(
          summary,
          isSelected: false,
          fillsWidth: true
        )
        .accessibilityLabel("응답 \(summary)")
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .background(
      FestiCoreSemanticColor.staticLime.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    )
  }

  /// Figma S07 F Actions: 가는 중(남은 너비)·확인, 간격 8. 고른 응답을 Static/Ink로 칠한다.
  func gatherActions(_ actions: FestivalCrewPresentation.Actions) -> some View {
    let goingSelected = actions.selected != .ack
    return HStack(spacing: FestiCoreSpacing.paddingP8) {
      Button { send(.gatherResponseTapped(.going)) } label: {
        gatherPill(
          actions.goingTitle,
          isSelected: goingSelected,
          fillsWidth: true
        )
      }
      .accessibilityAddTraits(actions.selected == .going ? .isSelected : [])
      Button { send(.gatherResponseTapped(.ack)) } label: {
        gatherPill(
          "확인",
          isSelected: !goingSelected,
          fillsWidth: false
        )
      }
      .accessibilityAddTraits(actions.selected == .ack ? .isSelected : [])
    }
    .buttonStyle(.plain)
    .disabled(actions.isResponding)
  }

  /// Figma S07 F 응답 버튼: 위아래 10·좌우 16, 모서리 10, Subheadline/Bold
  func gatherPill(
    _ title: String,
    isSelected: Bool,
    fillsWidth: Bool
  ) -> some View {
    return Text(title)
      .festiCoreFont(.baseSubheadlineBold)
      .festiCoreLineBox(.baseSubheadlineBold)
      .lineLimit(1)
      .foregroundStyle(isSelected
        ? FestiCoreSemanticColor.staticWhite.color
        : FestiCoreSemanticColor.staticInk.color)
      .padding(
        .vertical,
        Metric.gatherActionVertical
      )
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )
      .frame(maxWidth: fillsWidth ? .infinity : nil)
      .background(
        isSelected
          ? FestiCoreSemanticColor.staticInk.color
          : FestiCoreSemanticColor.staticalphaBlack20.color,
        in: RoundedRectangle(cornerRadius: Metric.gatherActionRadius)
      )
      .contentShape(Rectangle())
  }

  @ViewBuilder
  func summaryRow(_ presentation: FestivalCrewPresentation) -> some View {
    HStack(spacing: FestiCoreSpacing.marginM12) {
      summaryText(presentation)
      if let url = store.inviteURL {
        inviteButton(url)
      }
    }
    .frame(height: Metric.summaryHeight)
  }

  /// Figma S07 Summary 글자: Footnote/Regular · Label/Neutral
  func summaryText(_ presentation: FestivalCrewPresentation) -> some View {
    return Text(presentation.summary)
      .festiCoreFont(.baseFootnoteRegular)
      .festiCoreLineBox(.baseFootnoteRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      .lineLimit(1)
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
  }

  /// 초대 링크는 시스템 공유 시트로 보낸다. 모양은 보조 버튼과 같다.
  func inviteButton(
    _ url: URL,
    title: String = "초대 링크"
  ) -> some View {
    return FCButton(title) {}
      .style(.secondary)
      .size(.medium)
      .allowsHitTesting(false)
      .overlay {
        ShareLink(item: url) {
          Color.clear
            .contentShape(Rectangle())
        }
        .accessibilityLabel("초대 링크 공유")
      }
  }

  @ViewBuilder
  func members(_ presentation: FestivalCrewPresentation) -> some View {
    if presentation.members.isEmpty, store.load == .loading {
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: Metric.skeletonHeight)
        .accessibilityLabel("크루원을 불러오는 중")
    } else if presentation.members.isEmpty, store.load == .failed {
      FCEmptyCard(
        title: "크루를 불러오지 못했어요",
        message: "연결을 확인한 뒤 다시 시도해 주세요."
      )
      .action(FCCardAction("다시 시도") { send(.retryTapped) })
    } else {
      // Figma S07 Crew Card: 머리(크루원 · 4 / 12) 아래 크루원 줄. 테두리 없이 Background/Elevated
      VStack(spacing: .zero) {
        cardHeader(presentation)
        ForEach(presentation.members) { member in
          memberRow(member)
        }
        if presentation.members.count == 1, !presentation.isArchived {
          aloneEmpty
        }
      }
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
    }
  }

  /// Figma S07 Crew Card Header: 위 16·아래 4·좌우 16
  func cardHeader(_ presentation: FestivalCrewPresentation) -> some View {
    return HStack(spacing: FestiCoreSpacing.paddingP8) {
      Text("크루원")
        .festiCoreFont(.baseHeadlineBold)
        .festiCoreLineBox(.baseHeadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: .zero)
      Text(presentation.memberCount)
        .festiCoreFont(.baseFootnoteMedium)
        .festiCoreLineBox(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
    .padding(
      .top,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP4
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
  }

  /// Figma S07 C 혼자만 있음: 아이콘 원 48, 제목, 안내, 초대 링크 보내기
  var aloneEmpty: some View {
    return VStack(spacing: FestiCoreSpacing.marginM12) {
      Image(asset: .users24)
        .resizable()
        .frame(
          width: Metric.emptyIconSize,
          height: Metric.emptyIconSize
        )
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .frame(
          width: Metric.emptyBadgeSize,
          height: Metric.emptyBadgeSize
        )
        .background(
          FestiCoreSemanticColor.fillNormal.color,
          in: Circle()
        )
        .accessibilityHidden(true)
      Text("아직 아무도 안 들어왔어요")
        .festiCoreFont(.baseHeadlineBold)
        .festiCoreLineBox(.baseHeadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text("초대 링크를 단톡방에 보내 보세요 · 48시간 유효")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .multilineTextAlignment(.center)
      if let url = store.inviteURL {
        inviteButton(
          url,
          title: "초대 링크 보내기"
        )
      }
    }
    .frame(maxWidth: .infinity)
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP24
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
  }

  /// `FCCrewRow`와 같은 구성. 존이 없으면 칩을 그리지 않는다.
  func memberRow(_ member: FestivalCrewPresentation.Member) -> some View {
    let primary = member.isInactive ? FestiCoreSemanticColor.labelAssistive : .labelNormal
    // Figma S07 Crew Row(DesignKit FCCrewRow): 아바타와 이름 사이 간격 16
    return HStack(spacing: FestiCoreSpacing.paddingP16) {
      FCAvatar(member.nickname)
      // Figma S07 Crew Row(높이 82): 이름 줄 상자 24 + 간격 8 + 존 칩 26
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP8
      ) {
        HStack(spacing: FestiCoreSpacing.paddingP4) {
          Text(member.nickname)
            .festiCoreFont(.baseCalloutBold)
            .festiCoreLineBox(.baseCalloutBold)
            .foregroundStyle(primary.color)
          if member.isMe {
            FCTag("나")
          }
        }
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          if let zone = member.zone {
            FCZoneChip(zone) {}
              .allowsHitTesting(false)
          }
          if let status = member.status {
            Text(status)
              .festiCoreFont(.baseFootnoteBold)
              .festiCoreLineBox(.baseFootnoteBold)
              .foregroundStyle(primary.color)
          }
        }
      }
      .lineLimit(1)
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      if let time = member.time {
        Text(time)
          .festiCoreFont(.baseCaption1Regular)
          .festiCoreLineBox(.baseCaption1Regular)
          .foregroundStyle(member.isInactive
            ? FestiCoreSemanticColor.labelDisable.color
            : FestiCoreSemanticColor.labelAssistive.color)
      }
    }
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP12
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .opacity(member.isInactive ? Metric.inactiveOpacity : 1)
    .accessibilityElement(children: .combine)
  }

  var statusPanel: some View {
    // Figma S07 My Status(457-20938): 위 12·아래 8·좌우 16, 간격 10, 안내 Caption1/Medium
    return VStack(
      alignment: .leading,
      spacing: Metric.statusSpacing
    ) {
      Text("내 상태 · 탭 한 번이면 크루원에게 공유돼요")
        .festiCoreFont(.baseCaption1Medium)
        .festiCoreLineBox(.baseCaption1Medium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        ForEach(
          FestivalCrewState.allCases,
          id: \.self
        ) { crewState in
          stateButton(crewState)
        }
      }
    }
    .padding(
      .top,
      FestiCoreSpacing.paddingP12
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    // 하단 안전 영역이 없는 기기에서도 버튼이 바닥에 붙지 않도록 아래 8을 둔다.
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP8
    )
    .frame(maxWidth: .infinity)
    .background(FestiCoreSemanticColor.backgroundElevated.color.ignoresSafeArea(edges: .bottom))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(FestiCoreSemanticColor.lineNormal.color)
        .frame(height: Metric.borderWidth)
    }
  }

  func stateButton(_ crewState: FestivalCrewState) -> some View {
    // Figma S07 Crew Status Button = Big Button small(80×64)
    return FCBigButton(
      FestivalLiveBoardPresentation.crewStateText(crewState.rawValue) ?? "",
      sub: "",
      icon: icon(crewState)
    ) {
      send(.stateTapped(crewState))
    }
    .size(.small)
    .isSelected(store.myState == crewState)
    .disabled(store.crew?.archivedAt != nil)
  }

  func icon(_ crewState: FestivalCrewState) -> ImageAsset {
    switch crewState {
    case .here: return .locationDot20
    case .eating: return .clock20
    case .toilet: return .circleInfo20
    case .leaving: return .route24
    }
  }

  @ViewBuilder
  var toast: some View {
    if let toast = store.toast {
      FCToast(toastItem(toast))
        .padding(
          .top,
          Metric.toastTop
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  func toastItem(_ toast: FestivalCrewFeature.Toast) -> FCToast.Item {
    switch toast {
    case .inviteRotated:
      return FCToast.Item(
        icon: .check,
        message: "새 초대 링크를 만들었어요"
      )
    case .renamed:
      return FCToast.Item(
        icon: .check,
        message: "크루 이름을 바꿨어요"
      )
    case let .transferred(nickname):
      return FCToast.Item(
        icon: .check,
        message: "\(nickname)님이 크루장이 됐어요"
      )
    case let .removed(nickname):
      return FCToast.Item(
        icon: .check,
        message: "\(nickname)님을 내보냈어요"
      )
    case .statusFailed:
      return FCToast.Item(
        icon: .circleInfo16,
        message: "상태를 보내지 못했어요. 다시 눌러 주세요"
      )
    case .gatherExpired:
      return FCToast.Item(
        icon: .circleInfo16,
        message: "모여 요청이 끝나서 응답하지 못했어요"
      )
    }
  }

  enum Metric {
    static let refreshInterval: TimeInterval = 30
    static let summaryHeight: CGFloat = 40
    static let statusSpacing: CGFloat = 10
    static let emptyBadgeSize: CGFloat = 48
    static let emptyIconSize: CGFloat = 24
    static let skeletonHeight: CGFloat = 322
    static let borderWidth: CGFloat = 1
    static let inactiveOpacity: Double = 0.6
    static let toastTop: CGFloat = 30
    static let toastAnimation: Double = 0.25
    static let gatherIconSize: CGFloat = 20
    /// Figma S07 F 응답 버튼 모서리 10. 같은 값의 Radius 토큰이 없어 화면 값으로 둔다.
    static let gatherActionRadius: CGFloat = 10
    static let gatherActionVertical: CGFloat = 10
  }
}
