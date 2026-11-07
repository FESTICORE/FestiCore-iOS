import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// 축제 목록과 라이브 보드에서 같은 북마크 결과를 표시한다.
/// 사용자 결정: 토스트는 화면 위에서 아래로 내려온다. 시안의 하단 위치로 옮기지 않는다.
struct FestivalToastView: View {
  let toast: FestivalFeature.Toast
  let revision: Int

  var body: some View {
    FCToast(item)
      .iconColor(toast == .bookmarked ? FestiCoreSemanticColor.staticLime.color : FestiCoreSemanticColor.staticWhite.color)
      .id(revision)
      .padding(
        .top,
        30
      )
      .transition(.move(edge: .top).combined(with: .opacity))
  }
}

private extension FestivalToastView {
  var item: FCToast.Item {
    switch toast {
    case .bookmarked: .booked()
    case .unbookmarked: .unbooked()
    case .ticketLinkMissing: .noLink()
    case .packDownloadFailed: .init(
      icon: .circleInfo16,
      message: "팩을 받지 못했어요. 다시 시도해 주세요"
    )
    }
  }
}
