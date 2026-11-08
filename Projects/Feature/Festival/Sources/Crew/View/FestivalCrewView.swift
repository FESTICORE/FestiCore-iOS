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
        statusPanel
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
    return bar.trailingAction(
      icon: .magnifyingGlass,
      accessibilityLabel: "크루장 메뉴"
    ) { send(.menuTapped) }
  }

  @ViewBuilder
  func content(_ presentation: FestivalCrewPresentation) -> some View {
    ScrollView {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.marginM12
      ) {
        summaryRow(presentation)
        FCButton(presentation.gatherTitle) { send(.gatherTapped) }
          .isFullWidth(true)
          .isEnabled(presentation.canGather)
        if let notice = presentation.gatherNotice {
          gatherNotice(notice)
        }
        members(presentation)
      }
      .padding(FestiCoreSpacing.paddingP16)
    }
    .scrollBounceBehavior(.basedOnSize)
  }

  @ViewBuilder
  func summaryRow(_ presentation: FestivalCrewPresentation) -> some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      Text(presentation.summary)
        .festiCoreFont(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .lineLimit(1)
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
      if let url = store.inviteURL {
        inviteButton(url)
      }
    }
    .frame(height: Metric.summaryHeight)
  }

  /// 초대 링크는 시스템 공유 시트로 보낸다. 모양은 보조 버튼과 같다.
  func inviteButton(_ url: URL) -> some View {
    return FCButton("초대 링크") {}
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

  func gatherNotice(_ notice: String) -> some View {
    return HStack(spacing: Metric.noticeSpacing) {
      Image(asset: .circleCheck16)
        .resizable()
        .frame(
          width: Metric.noticeIconSize,
          height: Metric.noticeIconSize
        )
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityHidden(true)
      Text(notice)
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(1)
        .minimumScaleFactor(Metric.minimumScale)
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP12
    )
    .frame(
      maxWidth: .infinity,
      minHeight: Metric.noticeHeight,
      alignment: .leading
    )
    .background(
      FestiCoreSemanticColor.fillNormal.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    )
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
      VStack(spacing: .zero) {
        ForEach(presentation.members) { member in
          memberRow(member)
        }
      }
      .padding(
        .vertical,
        FestiCoreSpacing.paddingP4
      )
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
      .overlay {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .strokeBorder(
            FestiCoreSemanticColor.lineNormal.color,
            lineWidth: Metric.borderWidth
          )
      }
    }
  }

  /// `FCCrewRow`와 같은 구성. 존이 없으면 칩을 그리지 않는다.
  func memberRow(_ member: FestivalCrewPresentation.Member) -> some View {
    let primary = member.isInactive ? FestiCoreSemanticColor.labelAssistive : .labelNormal
    return HStack(spacing: FestiCoreSpacing.paddingP16) {
      FCAvatar(member.nickname)
      // Figma S07 Crew Row(높이 78): 이름 줄 상자 24 + 간격 4 + 존 칩 26
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP4
      ) {
        Text(member.nickname)
          .festiCoreFont(.baseCalloutBold)
          .festiCoreLineBox(.baseCalloutBold)
          .foregroundStyle(primary.color)
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          if let zone = member.zone {
            FCZoneChip(zone) {}
              .allowsHitTesting(false)
          }
          if let status = member.status {
            Text(status)
              .festiCoreFont(.baseFootnoteBold)
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
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text("내 상태 · 탭 한 번이면 공유돼요")
        .festiCoreFont(.baseCaption1Bold)
        .festiCoreLineBox(.baseCaption1Bold)
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
      Metric.panelTopPadding
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .bottom,
      Metric.panelBottomPadding
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
    let isSelected = store.myState == crewState
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    return Button { send(.stateTapped(crewState)) } label: {
      VStack(spacing: FestiCoreSpacing.paddingP4) {
        Image(asset: icon(crewState))
          .resizable()
          .scaledToFit()
          .frame(
            width: Metric.stateIconSize,
            height: Metric.stateIconSize
          )
          .accessibilityHidden(true)
        Text(FestivalLiveBoardPresentation.crewStateText(crewState.rawValue) ?? "")
          .festiCoreFont(.baseFootnoteBold)
          .festiCoreLineBox(.baseFootnoteBold)
          .lineLimit(1)
      }
      .foregroundStyle(isSelected
        ? FestiCoreSemanticColor.inverseLabel.color
        : FestiCoreSemanticColor.labelNormal.color)
      .frame(
        maxWidth: .infinity,
        minHeight: Metric.stateHeight
      )
      .background(
        isSelected ? FestiCoreSemanticColor.inverseBackground.color : FestiCoreSemanticColor.fillNormal.color,
        in: shape
      )
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .disabled(store.crew?.archivedAt != nil)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    }
  }

  enum Metric {
    static let refreshInterval: TimeInterval = 30
    static let summaryHeight: CGFloat = 40
    static let noticeHeight: CGFloat = 42
    static let noticeIconSize: CGFloat = 16
    static let noticeSpacing: CGFloat = 6
    static let minimumScale: CGFloat = 0.8
    static let skeletonHeight: CGFloat = 322
    static let borderWidth: CGFloat = 1
    static let inactiveOpacity: Double = 0.6
    static let panelTopPadding: CGFloat = 13
    static let panelBottomPadding: CGFloat = 1
    static let stateHeight: CGFloat = 66
    static let stateIconSize: CGFloat = 20
    static let toastTop: CGFloat = 30
    static let toastAnimation: Double = 0.25
  }
}
