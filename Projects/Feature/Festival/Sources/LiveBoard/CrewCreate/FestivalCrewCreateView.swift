import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI

/// 라이브 보드에서 push로 여는 크루 만들기 화면. 탭바 없이 아래 고정 버튼을 둔다.
/// 이름을 정해 만들면 같은 화면이 초대 단계로 바뀌어 크루장 전용 초대 링크를 보내고 크루 화면(S07)으로 갈 수 있다.
@ViewAction(for: FestivalCrewCreateFeature.self)
public struct FestivalCrewCreateView: View {
  @Bindable public var store: StoreOf<FestivalCrewCreateFeature>

  public init(store: StoreOf<FestivalCrewCreateFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      topBar
      ScrollView {
        content
          // Figma S07 B Contents: 좌우 16·위아래 24
          .padding(
            .horizontal,
            FestiCoreSpacing.paddingP16
          )
          .padding(
            .vertical,
            FestiCoreSpacing.paddingP24
          )
      }
      .scrollBounceBehavior(.basedOnSize)
    }
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
  }
}

private extension FestivalCrewCreateView {
  var topBar: some View {
    return FCTopBar(
      .back,
      title: "크루 만들기"
    )
    .onBack { send(.closeTapped) }
    .backgroundColor(.backgroundNavigation)
  }

  @ViewBuilder
  var content: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP24
    ) {
      switch store.step {
      case .naming:
        naming
      case let .created(crew):
        created(crew)
      }
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
  }

  @ViewBuilder
  var naming: some View {
    header(
      title: "크루 이름을 정해 주세요",
      message: "같이 온 친구들끼리만 서로 어느 존에 있는지 볼 수 있어요"
    )
    FCTextField(
      text: Binding(
        get: { store.name },
        set: { send(.nameChanged($0)) }
      ),
      placeholder: "예: 락린이들"
    )
    .label("크루 이름")
    .maxLength(20)
    .helper("단톡방 이름처럼 다들 알아보는 이름이 좋아요")
    .error(store.errorMessage)
    .disabled(store.isSubmitting)
    rules
  }

  /// Figma S07 B Info: Fill/Normal 상자 안 안내 세 줄(Footnote/Regular · Label/Neutral)
  var rules: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      ForEach(
        Metric.rules,
        id: \.self
      ) { rule in
        Text(rule)
          .festiCoreFont(.baseFootnoteRegular)
          .festiCoreLineBox(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .padding(FestiCoreSpacing.paddingP16)
    .background(
      FestiCoreSemanticColor.fillNormal.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    )
  }

  @ViewBuilder
  func created(_ crew: FestivalCrew) -> some View {
    header(
      title: "\(crew.name) 크루를 만들었어요",
      message: "초대 링크를 받은 사람은 바로 크루에 참여할 수 있어요."
    )
    if let code = crew.inviteCode {
      inviteCode(
        code,
        expiresAt: crew.inviteExpiresAt
      )
    }
  }

  func header(
    title: String,
    message: String
  ) -> some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text(title)
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text(message)
        .festiCoreFont(.baseSubheadlineRegular)
        .festiCoreLineBox(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  /// 아래 고정 버튼. 이름 단계는 만들기, 초대 단계는 링크 보내기·크루 보기다.
  var footer: some View {
    return VStack(spacing: FestiCoreSpacing.paddingP12) {
      switch store.step {
      case .naming:
        FCButton(store.isSubmitting ? "만드는 중" : "만들고 초대 링크 받기") { send(.submitTapped) }
          .isFullWidth(true)
          .isEnabled(store.canSubmit)
      case .created:
        if let url = store.inviteURL {
          shareButton(url)
        }
        FCButton("크루 보기") { send(.openCrewTapped) }
          .style(store.inviteURL == nil ? .primary : .secondary)
          .isFullWidth(true)
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
        .frame(height: Metric.divider)
    }
  }

  /// 크루장 전용 초대 코드와 만료 시각(서버 기준 48시간)
  func inviteCode(
    _ code: String,
    expiresAt: Date?
  ) -> some View {
    return VStack(spacing: FestiCoreSpacing.paddingP4) {
      Text(code)
        .festiCoreFont(.baseTitle1Bold)
        .festiCoreLineBox(.baseTitle1Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityLabel("초대 코드 \(code.map(String.init).joined(separator: " "))")
      if let expiresAt {
        Text("\(expiresAt.formatted(.festivalDay)) \(expiresAt.formatted(.time))까지 쓸 수 있어요")
          .festiCoreFont(.baseFootnoteRegular)
          .festiCoreLineBox(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP16
    )
    .background(
      FestiCoreSemanticColor.fillNormal.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    )
  }

  /// 초대 링크는 시스템 공유 시트로 보낸다. 모양은 기본 버튼과 같다.
  func shareButton(_ url: URL) -> some View {
    return FCButton("초대 링크 보내기") {}
      .isFullWidth(true)
      .allowsHitTesting(false)
      .overlay {
        ShareLink(
          item: url,
          message: Text("FestiCore 크루에 초대해요")
        ) {
          Color.clear
            .contentShape(Rectangle())
        }
        .accessibilityLabel("초대 링크 보내기")
      }
  }

  /// 하단 고정 영역은 크루 참여 확인(S08)과 같은 여백을 쓴다.
  enum Metric {
    static let footerTopPadding: CGFloat = 13
    static let footerBottomPadding: CGFloat = 1
    static let divider: CGFloat = 1
    static let rules = [
      "· 최대 \(FestivalCrew.maxMembers)명 · 페스티벌마다 크루 1개",
      "· 초대 링크는 48시간 동안 쓸 수 있어요",
      "· 페스티벌이 끝나면 기록만 남아요",
    ]
  }
}
