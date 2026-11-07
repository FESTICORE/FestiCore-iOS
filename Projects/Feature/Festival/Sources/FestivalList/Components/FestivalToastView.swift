import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// 축제 목록의 북마크·예매처·팩 결과를 화면 아래쪽에 표시한다(Figma S00 전체_북마크: 하단 안전 영역 위 16pt).
struct FestivalToastView: View {
  let toast: FestivalFeature.Toast
  let revision: Int

  var body: some View {
    FCToast(item)
      .iconColor(toast == .bookmarked ? FestiCoreSemanticColor.staticLime.color : FestiCoreSemanticColor.staticWhite.color)
      .id(revision)
      .padding(
        .bottom,
        FestiCoreSpacing.paddingP16
      )
      .transition(.move(edge: .bottom).combined(with: .opacity))
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
