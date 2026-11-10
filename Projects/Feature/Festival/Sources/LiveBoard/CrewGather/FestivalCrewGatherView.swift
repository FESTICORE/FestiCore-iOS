import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

@ViewAction(for: FestivalCrewGatherFeature.self)
struct FestivalCrewGatherView: View {
  @Bindable var store: StoreOf<FestivalCrewGatherFeature>

  var body: some View {
    return VStack(spacing: FestiCoreSpacing.paddingP16) {
      Text("모일 존을 선택해 주세요")
        .festiCoreFont(.baseHeadlineBold)
        .festiCoreLineBox(.baseHeadlineBold)
      if store.zones.isEmpty {
        FCEmptyCard(
          title: "공개된 존이 없어요",
          message: "공식 존 정보가 공개되면 집결을 요청할 수 있어요."
        )
      }
      ScrollView {
        VStack(spacing: FestiCoreSpacing.paddingP8) {
          ForEach(
            store.zones,
            id: \.id
          ) { zone in
            FCListRow(zone.name) { send(.zoneTapped(zone.id)) }
              .overlay(alignment: .trailing) {
                if store.selectedZoneID == zone.id {
                  Image(asset: .check)
                    .padding(
                      .trailing,
                      FestiCoreSpacing.paddingP16
                    )
                }
              }
          }
        }
      }
      .frame(maxHeight: 240)
      FCButton(store.isSubmitting ? "요청 중" : "모여!") { send(.submitTapped) }
        .isFullWidth(true)
        .isEnabled(store.selectedZoneID != nil && !store.isSubmitting)
    }
    .padding(FestiCoreSpacing.paddingP20)
    .fcAlert($store.scope(
      state: \.alert,
      action: \.alert
    ))
  }
}
