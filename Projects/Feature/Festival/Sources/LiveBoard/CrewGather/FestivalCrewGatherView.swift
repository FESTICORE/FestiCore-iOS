import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// Figma S07 E "모여!" 존 고르기. 기수 존 시트(Bearer Choice Sheet 290:531)를 재사용해 2열 타일을 두고 누르면 바로 보낸다.
@ViewAction(for: FestivalCrewGatherFeature.self)
struct FestivalCrewGatherView: View {
  @Bindable var store: StoreOf<FestivalCrewGatherFeature>

  var body: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      header
      if store.zones.isEmpty {
        FCEmptyCard(
          title: "공개된 존이 없어요",
          message: "공식 존 정보가 공개되면 집결을 요청할 수 있어요."
        )
      } else {
        zoneGrid
      }
    }
    // 시트가 손잡이 아래 16pt를 두므로 위 여백은 넣지 않는다.
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP16
    )
    .fcAlert($store.scope(
      state: \.alert,
      action: \.alert
    ))
  }
}

private extension FestivalCrewGatherView {
  var header: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM4
    ) {
      Text("어디로 모일까요?")
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
      Text(subtitle)
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
  }

  var subtitle: String {
    guard let count = store.recipientCount, count > 0 else {
      return "누르면 바로 크루원에게 소리 알림이 가요"
    }
    return "누르면 바로 크루원 \(count)명에게 소리 알림이 가요"
  }

  // 시트는 내용 높이를 따르고, 존이 많으면 최대 높이 안에서 스크롤한다.
  var zoneGrid: some View {
    return ScrollView {
      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: FestiCoreSpacing.marginM12
      ) {
        ForEach(
          store.zones,
          id: \.id
        ) { zone in
          FCChoiceTile(
            zone.name,
            icon: .locationDot16
          ) {
            send(.zoneTapped(zone.id))
          }
          .isSelected(zone.id == store.selectedZoneID)
        }
      }
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(height: gridHeight)
    .disabled(store.isSubmitting)
  }

  var gridHeight: CGFloat {
    let rows = CGFloat((store.zones.count + 1) / 2)
    let gaps = max(
      0,
      rows - 1
    )
    let content = rows * Metric.tileHeight + gaps * FestiCoreSpacing.marginM12
    return min(
      content,
      Metric.maxGridHeight
    )
  }

  enum Metric {
    static let tileHeight: CGFloat = 44
    static let maxGridHeight: CGFloat = 420
  }
}
