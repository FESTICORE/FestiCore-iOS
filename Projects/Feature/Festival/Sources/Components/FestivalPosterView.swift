import FestiCoreSharedUI
import SwiftUI

struct FestivalPosterView: View {
  let url: URL?
  let imageRevision: Int

  var body: some View {
    GeometryReader { geometry in
      FCRemoteImage(url: url)
        .content(.fill)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        // clipped는 그리기만 자르고 터치 영역은 넘친 이미지 크기 그대로 남긴다.
        // 세로로 긴 포스터가 옆 카드의 탭을 가로채지 않게 이미지는 터치를 받지 않는다.
        .allowsHitTesting(false)
        .id("\(url?.absoluteString ?? "")-\(imageRevision)")
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .contentShape(Rectangle())
  }
}
