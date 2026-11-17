import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: FestivalSwitcherFeature.self)
public struct FestivalSwitcherView: View {
  public let store: StoreOf<FestivalSwitcherFeature>

  public init(store: StoreOf<FestivalSwitcherFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      heading()
      ScrollView {
        LazyVStack(spacing: .zero) {
          ForEach(store.festivals) { festival in
            festivalRow(festival)
          }
        }
      }
      .scrollIndicators(.hidden)
      .frame(height: min(
        CGFloat(store.festivals.count) * 68,
        204
      ))

      // Figma Festival Switch Sheet: 목록·구분선·전체 보기 행 사이 8
      Rectangle()
        .fill(FestiCoreSemanticColor.lineNormal.color)
        .frame(height: 1)
        .padding(
          .vertical,
          FestiCoreSpacing.paddingP8
        )

      allFestivalsRow
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP20
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP8
    )
    .background(FestiCoreSemanticColor.backgroundElevated.color)
  }
}

private extension FestivalSwitcherView {
  @ViewBuilder
  func heading() -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP4
    ) {
      Text("페스티벌 바꾸기")
        .festiCoreFont(.baseTitle3Bold)
        .festiCoreLineBox(.baseTitle3Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text("내가 예매한 페스티벌")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP12
    )
  }

  func festivalRow(_ festival: FestivalSwitcherFeature.State.Item) -> some View {
    let isSelected = festival.id == store.selectedFestivalID
    return Button { send(.festivalTapped(festival.id)) } label: {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        FestivalPosterView(
          url: festival.thumbnailURL,
          imageRevision: 0
        )
          .frame(
            width: 44,
            height: 44
          )
          // Figma Thumbnail 모서리 12
          .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
          .accessibilityHidden(true)
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.marginM2
        ) {
          Text(festival.name)
            .festiCoreFont(.baseCalloutMedium)
            .festiCoreLineBox(.baseCalloutMedium)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .lineLimit(1)
          Text(festival.subtitle)
            .festiCoreFont(.baseFootnoteRegular)
            .festiCoreLineBox(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            .lineLimit(1)
        }
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
        if isSelected {
          Image(asset: .check)
            .resizable()
            .frame(
              width: 20,
              height: 20
            )
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .accessibilityHidden(true)
        }
      }
      .frame(height: 68)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(festival.name), \(festival.subtitle)")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityHint("페스티벌 라이브 보드로 이동합니다")
  }

  var allFestivalsRow: some View {
    Button { send(.allFestivalsTapped) } label: {
      HStack {
        Text("전체 페스티벌 보기")
          .festiCoreFont(.baseBodyRegular)
          .festiCoreLineBox(.baseBodyRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Spacer()
        Image(asset: .chevronRight16)
          .resizable()
          .frame(
            width: 16,
            height: 16
          )
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .accessibilityHidden(true)
      }
      .frame(height: 56)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityHint("페스티벌 목록으로 이동합니다")
  }
}
