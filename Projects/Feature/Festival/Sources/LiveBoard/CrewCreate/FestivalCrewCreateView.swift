import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// 라이브 보드의 크루 만들기 바텀시트 내용. 부모가 `fcModal`로 표시한다.
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
      header()
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
      .disabled(store.isSubmitting)

      FCPrimaryButton(
        store.isSubmitting ? "만드는 중" : "크루 만들기",
        isEnabled: store.canSubmit
      ) {
        send(.submitTapped)
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
    .fcAlert(
      $store.scope(
        \.alert,
        action: \.scope.alert
      )
    )
  }
}

private extension FestivalCrewCreateView {
  @ViewBuilder
  func header() -> some View {
    HStack(
      alignment: .top,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP8
      ) {
        Text("크루 만들기")
          .festiCoreFont(.baseTitle2Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityAddTraits(.isHeader)
        Text("함께 페스티벌을 즐길 크루의 이름을 정해 주세요.")
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      Spacer(minLength: .zero)
      Button { send(.closeTapped) } label: {
        Image(asset: .xmark16)
          .resizable()
          .frame(
            width: 20,
            height: 20
          )
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      .buttonStyle(.plain)
      .disabled(store.isSubmitting)
      .accessibilityLabel("닫기")
    }
  }
}
