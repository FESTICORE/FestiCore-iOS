import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

public struct FestivalFlagView: View {
  @Bindable private var store: StoreOf<FestivalFlagFeature>

  public init(store: StoreOf<FestivalFlagFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
        Text("깃발")
          .festiCoreFont(.baseTitle1Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)

        if store.festivalID == nil {
          FCEmptyCard(title: "축제를 선택해 주세요", message: "축제를 선택하면 해당 축제의 깃발을 볼 수 있습니다.")
        } else {
          content
        }
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP20)
      .padding(.top, FestiCoreSpacing.paddingP24)
      .padding(.bottom, FestiCoreSpacing.paddingP24)
    }
    .scrollIndicators(.hidden)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .refreshable { store.send(.refresh) }
    .onAppear { store.send(.appeared) }
    .onDisappear { store.send(.disappeared) }
  }

  @ViewBuilder
  private var content: some View {
    if let snapshot = store.snapshot {
      if store.viewState == .failed {
        FCEmptyCard(title: "새 정보를 불러오지 못했습니다", message: "이전에 받은 깃발을 표시합니다. 아래로 당겨 다시 시도해 주세요.")
      }
      flagSection(title: "팔로우한 깃발", flags: snapshot.followedFlags)
      flagSection(title: "활성 깃발", flags: snapshot.activeFlags)
    } else {
      switch store.viewState {
      case .idle, .loading:
        ProgressView("깃발을 불러오는 중입니다")
          .frame(maxWidth: .infinity, minHeight: 180)
      case .failed:
        FCEmptyCard(title: "깃발을 불러오지 못했습니다", message: "네트워크 연결을 확인하고 아래로 당겨 다시 시도해 주세요.")
      case .loaded:
        FCEmptyCard(title: "깃발이 없습니다", message: "이 축제에 등록된 깃발이 없습니다.")
      }
    }
  }

  private func flagSection(title: String, flags: [FestivalLiveBoardSnapshot.Flag]) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Text(title)
        .festiCoreFont(.baseTitle3Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      if flags.isEmpty {
        FCEmptyCard(title: title, message: "표시할 깃발이 없습니다.")
      } else {
        ForEach(flags) { flag in
          HStack(spacing: FestiCoreSpacing.paddingP12) {
            FCRemoteImage(url: flag.thumbnailURL)
              .frame(width: 48, height: 48)
              .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
            VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
              Text(flag.name)
                .festiCoreFont(.baseSubheadlineBold)
                .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
              Text([flag.zoneID, flag.activity, statusLabel(flag.status)]
                .compactMap { $0 }.joined(separator: " · "))
                .festiCoreFont(.baseCaption1Regular)
                .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            }
            Spacer(minLength: 0)
          }
          .padding(FestiCoreSpacing.paddingP12)
          .background(FestiCoreSemanticColor.backgroundElevated.color,
                      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
        }
      }
    }
  }

  private func statusLabel(_ status: String) -> String? {
    switch status {
    case "active": "활동 중"
    case "resting": "휴식 중"
    case "ended": "종료"
    default: nil
    }
  }
}
