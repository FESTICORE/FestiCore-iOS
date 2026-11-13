import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

/// 라이브 보드 `활성 깃발` 섹션. 라이브 보드 자식 store의 응답 상태만 읽고 `다시 시도`를 자식 액션으로 보낸다.
@ViewAction(for: FestivalLiveBoardFeature.self)
struct FestivalLiveBoardActiveFlagSection: View {
  let store: StoreOf<FestivalLiveBoardFeature>
  /// 깃발 구역 이름을 찾는 표시용 팩. 부모 화면이 넘긴다.
  let pack: FestivalPackDocument?
  let now: Date

  init(
    store: StoreOf<FestivalLiveBoardFeature>,
    pack: FestivalPackDocument?,
    now: Date
  ) {
    self.store = store
    self.pack = pack
    self.now = now
  }

  var body: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      FCSectionHeader("활성 깃발")
        .action("최근 업데이트 순")
      if let active = store.snapshot?.activeFlags, !active.isEmpty {
        VStack(spacing: .zero) {
          ForEach(FestivalLiveBoardPresentation.sortedActiveFlags(active)) { flag in
            FestivalLiveBoardActiveFlagRow(flag: presentation(
              flag,
              now: now
            ))
          }
        }
        .background(FestiCoreSemanticColor.backgroundElevated.color)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      } else if store.snapshot == nil, !store.isUnavailable {
        FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
          .frame(height: 228)
          .accessibilityLabel("활성 깃발을 불러오는 중")
      } else if store.snapshot == nil {
        FCEmptyCard(
          icon: .flag20,
          title: "활성 깃발을 불러오지 못했어요",
          message: loadingMessage
        )
        .action(FCCardAction("다시 시도") { send(.retryTapped) })
      } else {
        FCEmptyCard(
          icon: .flag20,
          title: "활동 중인 깃발이 없어요",
          message: "깃발이 움직이면 여기에서 바로 보여 드려요."
        )
      }
    }
  }
}

private extension FestivalLiveBoardActiveFlagSection {
  func presentation(
    _ flag: FestivalLiveBoardSnapshot.Flag,
    now: Date
  ) -> FestivalLiveBoardPresentation.Flag {
    return FestivalLiveBoardPresentation.flag(
      flag,
      zoneName: { pack?.zoneName(for: $0) },
      now: now
    )
  }

  var loadingMessage: String {
    return store.isUnavailable ? "실시간 정보를 불러올 수 없습니다. 잠시 후 다시 시도합니다." : "실시간 정보를 불러오는 중입니다."
  }
}
