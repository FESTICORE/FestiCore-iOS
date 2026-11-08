import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI

/// 라이브 보드의 크루 만들기 바텀시트 내용. 부모가 `fcModal`로 표시한다.
/// 이름을 정해 만들면 같은 시트에서 크루장 전용 초대 링크를 보내고 크루 화면(S07)으로 갈 수 있다.
@ViewAction(for: FestivalCrewCreateFeature.self)
public struct FestivalCrewCreateView: View {
  @Bindable public var store: StoreOf<FestivalCrewCreateFeature>

  public init(store: StoreOf<FestivalCrewCreateFeature>) {
    self.store = store
  }

  public var body: some View {
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
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP20
    )
    .padding(
      .top,
      FestiCoreSpacing.paddingP8
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP24
    )
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .fcAlert($store.scope(
      state: \.alert,
      action: \.alert
    ))
  }
}

private extension FestivalCrewCreateView {
  @ViewBuilder
  var naming: some View {
    header(
      title: "크루 만들기",
      message: "함께 페스티벌을 즐길 크루의 이름을 정해 주세요."
    )
    FCTextField(
      text: Binding(
        get: { store.name },
        set: { send(.nameChanged($0)) }
      ),
      placeholder: "크루 이름을 입력해 주세요"
    )
    .label("크루 이름")
    .maxLength(20)
    .helper("1~20자로 입력해 주세요")
    .error(store.errorMessage)
    .disabled(store.isSubmitting)

    FCPrimaryButton(
      store.isSubmitting ? "만드는 중" : "크루 만들기",
      isEnabled: store.canSubmit
    ) {
      send(.submitTapped)
    }
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
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      if let url = store.inviteURL {
        shareButton(url)
      }
      FCButton("크루 보기") { send(.openCrewTapped) }
        .style(store.inviteURL == nil ? .primary : .secondary)
        .isFullWidth(true)
    }
  }

  func header(
    title: String,
    message: String
  ) -> some View {
    return HStack(
      alignment: .top,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP8
      ) {
        Text(title)
          .festiCoreFont(.baseTitle2Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityAddTraits(.isHeader)
        Text(message)
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      Spacer(minLength: .zero)
      Button { send(.closeTapped) } label: {
        Image(asset: .xmark16)
          .resizable()
          .frame(
            width: Metric.closeIcon,
            height: Metric.closeIcon
          )
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      .buttonStyle(.plain)
      .disabled(store.isSubmitting)
      .accessibilityLabel("닫기")
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
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityLabel("초대 코드 \(code.map(String.init).joined(separator: " "))")
      if let expiresAt {
        Text("\(expiresAt.formatted(.festivalDay)) \(expiresAt.formatted(.time))까지 쓸 수 있어요")
          .festiCoreFont(.baseFootnoteRegular)
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

  enum Metric {
    static let closeIcon: CGFloat = 20
  }
}
