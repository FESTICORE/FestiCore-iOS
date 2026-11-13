import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

/// 라이브 보드 `내 크루` 섹션. 라이브 보드 자식 store의 응답 상태만 읽고 탭을 자식 액션으로 보낸다.
@ViewAction(for: FestivalLiveBoardFeature.self)
struct FestivalLiveBoardCrewSection: View {
  let store: StoreOf<FestivalLiveBoardFeature>
  /// 크루원 구역 이름을 찾는 표시용 팩. 부모 화면이 넘긴다.
  let pack: FestivalPackDocument?
  /// 인증 세션이 있는지. 부모 화면이 넘긴다.
  let hasSession: Bool
  /// 내 크루원 표시를 가르는 세션 사용자 ID. 부모 화면이 넘긴다.
  let sessionUserID: String?
  /// 모여! 버튼을 보일지(행사가 끝나지 않았는지). 부모 화면이 넘긴다.
  let showsGather: Bool
  /// 오프라인 상태를 표시 중인지. 부모 화면이 넘긴다.
  let showsOfflineStatus: Bool
  let now: Date

  init(
    store: StoreOf<FestivalLiveBoardFeature>,
    pack: FestivalPackDocument?,
    hasSession: Bool,
    sessionUserID: String?,
    showsGather: Bool,
    showsOfflineStatus: Bool,
    now: Date
  ) {
    self.store = store
    self.pack = pack
    self.hasSession = hasSession
    self.sessionUserID = sessionUserID
    self.showsGather = showsGather
    self.showsOfflineStatus = showsOfflineStatus
    self.now = now
  }

  var body: some View {
    if !hasSession {
      FestivalLiveBoardLoginCard(title: "크루와 함께 보려면 로그인") { send(.crewLoginTapped) }
    } else if let crew = store.snapshot?.crew {
      FestivalLiveBoardCrewCard(
        crew: FestivalLiveBoardPresentation.crew(
          crew,
          sessionUserID: sessionUserID,
          zoneName: { pack?.zoneName(for: $0) },
          now: now
        ),
        showsGather: showsGather,
        canGather: !showsOfflineStatus && (crew.gatherAvailableAt.map { $0 <= now } ?? true),
        onGather: {
          send(.gatherCrewTapped)
        },
        onZoneTap: { send(.crewZoneTapped($0)) },
        onOpen: {
          send(.crewTapped)
        }
      )
    } else if store.snapshot == nil, !store.isUnavailable {
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: 228)
        .accessibilityLabel("내 크루를 불러오는 중")
    } else if store.snapshot == nil {
      FCEmptyCard(
        title: "내 크루를 불러오지 못했어요",
        message: loadingMessage
      )
      .action(FCCardAction("다시 시도") { send(.retryTapped) })
    } else {
      FCEmptyCard(
        title: "아직 크루가 없어요",
        message: "친구를 초대하면 서로 어느 존에 있는지 바로 볼 수 있어요."
      )
      .action(FCCardAction(
        "크루 만들기",
        style: .primary
      ) { send(.createCrewTapped) })
    }
  }
}

private extension FestivalLiveBoardCrewSection {
  var loadingMessage: String {
    return store.isUnavailable ? "실시간 정보를 불러올 수 없습니다. 잠시 후 다시 시도합니다." : "실시간 정보를 불러오는 중입니다."
  }
}
