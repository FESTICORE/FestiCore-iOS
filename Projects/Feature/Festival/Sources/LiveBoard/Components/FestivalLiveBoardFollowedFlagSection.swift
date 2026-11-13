import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

/// 라이브 보드 `팔로우한 깃발` 섹션. 라이브 보드 자식 store의 응답 상태만 읽고 탭을 자식 액션으로 보낸다.
@ViewAction(for: FestivalLiveBoardFeature.self)
struct FestivalLiveBoardFollowedFlagSection: View {
  let store: StoreOf<FestivalLiveBoardFeature>
  /// 깃발 구역 이름을 찾는 표시용 팩. 부모 화면이 넘긴다.
  let pack: FestivalPackDocument?
  /// 인증 세션이 있는지. 부모 화면이 넘긴다.
  let hasSession: Bool
  /// 빈 팔로우 깃발 안내를 보일지. 부모 화면이 넘긴다.
  let showsFollowGuide: Bool
  let now: Date
  let festivalEnded: Bool

  init(
    store: StoreOf<FestivalLiveBoardFeature>,
    pack: FestivalPackDocument?,
    hasSession: Bool,
    showsFollowGuide: Bool,
    now: Date,
    festivalEnded: Bool
  ) {
    self.store = store
    self.pack = pack
    self.hasSession = hasSession
    self.showsFollowGuide = showsFollowGuide
    self.now = now
    self.festivalEnded = festivalEnded
  }

  var body: some View {
    if !(hasSession && store.snapshot != nil &&
      (store.snapshot?.followedFlags.isEmpty ?? true) && !showsFollowGuide) {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP16
      ) {
        FCSectionHeader("팔로우한 깃발")
        if !hasSession {
          FestivalLiveBoardLoginCard(title: "깃발을 팔로우하려면 로그인") { send(.followLoginTapped) }
        } else if let followed = store.snapshot?.followedFlags, !followed.isEmpty {
          ScrollView(.horizontal) {
            HStack(
              alignment: .top,
              spacing: FestiCoreSpacing.paddingP12
            ) {
              ForEach(followed) { flag in
                FestivalLiveBoardFlagTile(flag: FestivalLiveBoardPresentation.flag(
                  flag,
                  zoneName: { pack?.zoneName(for: $0) },
                  now: now,
                  festivalEnded: festivalEnded
                ))
              }
            }
            .padding(
              .trailing,
              FestiCoreSpacing.paddingP16
            )
          }
          .scrollIndicators(.hidden)
          .scrollClipDisabled()
        } else if store.snapshot == nil, !store.isUnavailable {
          FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
            .frame(height: 204)
            .accessibilityLabel("팔로우한 깃발을 불러오는 중")
        } else if store.snapshot == nil {
          FCEmptyCard(
            icon: .flag20,
            title: "팔로우한 깃발을 불러오지 못했어요",
            message: loadingMessage
          )
          .action(FCCardAction("다시 시도") { send(.retryTapped) })
        } else if showsFollowGuide {
          followGuideCard
        }
      }
    }
  }
}

private extension FestivalLiveBoardFollowedFlagSection {
  var followGuideCard: some View {
    // Figma S01 D: 팔로우 안내 Empty Card 아이콘은 flag 24다.
    return FCEmptyCard(
      icon: .flag,
      title: "만나보고 싶은 깃발이 있나요?",
      message: "팔로우하면 깃발이 움직일 때 조용히 알려 드려요."
    )
    .action(FCCardAction(
      "깃발 찾기",
      style: .primary
    ) { send(.findFlagTapped) })
    .overlay(alignment: .topTrailing) {
      Button { send(.hideFollowGuideTapped) } label: {
        // Figma Empty Card Close: xmark 16(Label/Assistive)
        Image(asset: .xmark16)
          .resizable()
          .frame(
            width: 16,
            height: 16
          )
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .frame(
            width: 44,
            height: 44
          )
          .contentShape(Rectangle())
      }
      .accessibilityLabel("깃발 안내 숨기기")
    }
  }

  var loadingMessage: String {
    return store.isUnavailable ? "실시간 정보를 불러올 수 없습니다. 잠시 후 다시 시도합니다." : "실시간 정보를 불러오는 중입니다."
  }
}
