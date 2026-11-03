import FestiCoreDesignKit
import SwiftUI

/// 축제 목록과 라이브 보드에서 같은 북마크 결과를 표시한다.
struct FestivalToastView: View {
  let toast: FestivalFeature.Toast
  let revision: Int

  var body: some View {
    FCToast(.init(icon: icon, message: message))
      .iconColor(toast == .bookmarked ? FestiCoreSemanticColor.staticLime.color : FestiCoreSemanticColor.staticWhite.color)
      .id(revision)
      .padding(.bottom, FestiCoreSpacing.paddingP16)
      .transition(.move(edge: .bottom).combined(with: .opacity))
  }
}

private extension FestivalToastView {
  var icon: ImageAsset {
    switch toast {
    case .bookmarked: .bookmark16
    case .unbookmarked: .xmark16
    case .ticketLinkMissing: .circleInfo16
    }
  }

  var message: String {
    switch toast {
    case .bookmarked: "내가 예매한 페스티벌에 담았어요"
    case .unbookmarked: "내가 예매한 페스티벌에서 제외했어요"
    case .ticketLinkMissing: "예매처 정보가 없습니다"
    }
  }
}
