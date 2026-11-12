import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// Figma S07 크루장 메뉴 바텀시트(65-4009). 이름 바꾸기와 크루원 고르기는 같은 시트 안에서 이어진다.
@ViewAction(for: FestivalCrewMenuFeature.self)
public struct FestivalCrewMenuView: View {
  @Bindable public var store: StoreOf<FestivalCrewMenuFeature>

  public init(store: StoreOf<FestivalCrewMenuFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(
      alignment: .leading,
      spacing: Metric.titleSpacing
    ) {
      Text(title)
        .festiCoreFont(.baseHeadlineBold)
        .festiCoreLineBox(.baseHeadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      step
    }
    // 시트가 손잡이 아래 여백을 두므로 위 여백은 시안과 맞춘 만큼만 줄인다.
    .padding(
      .top,
      Metric.topOffset
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
  }
}

private extension FestivalCrewMenuView {
  var title: String {
    switch store.step {
    case .menu: return "크루 관리"
    case .rename: return "크루 이름 바꾸기"
    case .transfer: return "누구에게 크루장을 넘길까요?"
    case .remove: return "누구를 내보낼까요?"
    }
  }

  @ViewBuilder
  var step: some View {
    switch store.step {
    case .menu:
      menu
    case .rename:
      rename
    case .transfer, .remove:
      memberList
    }
  }

  @ViewBuilder
  var menu: some View {
    VStack(
      alignment: .leading,
      spacing: Metric.rowSpacing
    ) {
      menuRow(
        "크루 이름 바꾸기",
        icon: Image(asset: .listCheck20)
      ) { send(.renameTapped) }
      menuRow(
        "초대 링크 다시 만들기",
        icon: Image(asset: .shareNodes)
      ) { send(.rotateInviteTapped) }
      menuRow(
        "크루장 넘기기",
        icon: Image(asset: .users24)
      ) { send(.transferTapped) }
      .disabled(store.members.isEmpty)
      menuRow(
        "크루원 내보내기",
        icon: Image(asset: .user24)
      ) { send(.removeTapped) }
      .disabled(store.members.isEmpty)
      menuRow(
        "크루 해산하기",
        icon: Image(asset: .circleXmark),
        isLast: true,
        tint: .labelNeutral,
        iconTint: .labelAssistive
      ) { send(.dissolveTapped) }
      Text("초대 링크를 다시 만들면 이전 링크는 바로 막혀요. 크루장은 넘기거나 해산해야 나갈 수 있어요.")
        .festiCoreFont(.baseCaption1Regular)
        .festiCoreLineBox(.baseCaption1Regular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
    .padding(
      .bottom,
      Metric.footnoteBottom
    )
  }

  func menuRow(
    _ title: String,
    icon: Image,
    isLast: Bool = false,
    tint: FestiCoreSemanticColor = .labelNormal,
    iconTint: FestiCoreSemanticColor? = nil,
    action: @escaping () -> Void
  ) -> some View {
    return Button(action: action) {
      HStack(spacing: FestiCoreSpacing.marginM12) {
        icon
          .resizable()
          .scaledToFit()
          .frame(
            width: Metric.iconSize,
            height: Metric.iconSize
          )
          .foregroundStyle((iconTint ?? tint).color)
          .accessibilityHidden(true)
        Text(title)
          .festiCoreFont(.baseBodyRegular)
          .festiCoreLineBox(.baseBodyRegular)
          .lineLimit(1)
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )
      }
      .foregroundStyle(tint.color)
      .padding(
        .leading,
        FestiCoreSpacing.paddingP4
      )
      .frame(height: isLast ? Metric.lastRowHeight : Metric.rowHeight)
      .overlay(alignment: .bottom) {
        if !isLast {
          Rectangle()
            .fill(FestiCoreSemanticColor.lineNormal.color)
            .frame(height: Metric.dividerHeight)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  var rename: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      FCTextField(
        text: $store.nameDraft,
        placeholder: "크루 이름"
      )
      .maxLength(Metric.nameLimit)
      .counter("\(store.nameDraft.count) / \(Metric.nameLimit)")
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        FCButton("이전") { send(.backTapped) }
          .style(.secondary)
        FCButton("저장") { send(.saveNameTapped) }
          .isFullWidth(true)
          .isEnabled(store.canSaveName)
      }
    }
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP16
    )
  }

  @ViewBuilder
  var memberList: some View {
    VStack(spacing: .zero) {
      ForEach(store.members) { member in
        Button { send(.memberTapped(member.id)) } label: {
          HStack(spacing: FestiCoreSpacing.marginM12) {
            FCAvatar(member.nickname)
            Text(member.nickname)
              .festiCoreFont(.baseBodyRegular)
              .festiCoreLineBox(.baseBodyRegular)
              .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
              .frame(
                maxWidth: .infinity,
                alignment: .leading
              )
          }
          .frame(height: Metric.rowHeight)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      FCButton("이전") { send(.backTapped) }
        .style(.secondary)
        .isFullWidth(true)
        .padding(
          .vertical,
          FestiCoreSpacing.paddingP16
        )
    }
  }

  enum Metric {
    static let topOffset: CGFloat = -4
    static let titleSpacing: CGFloat = 4
    static let rowSpacing: CGFloat = 4
    static let rowHeight: CGFloat = 59
    static let lastRowHeight: CGFloat = 58
    static let dividerHeight: CGFloat = 1
    static let iconSize: CGFloat = 20
    /// 시트 아래 안전 영역 여백이 시안(65-4009)보다 3pt 커서 그만큼 당긴다.
    static let footnoteBottom: CGFloat = -3
    static let nameLimit = 20
  }
}
