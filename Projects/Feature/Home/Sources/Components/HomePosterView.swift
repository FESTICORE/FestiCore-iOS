import FestiCoreSharedUI
import SwiftUI

struct HomePosterView: View {
  let url: URL?
  let imageRevision: Int

  var body: some View {
    GeometryReader { geometry in
      FCRemoteImage(url: url)
        .content(.fill)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        .id("\(url?.absoluteString ?? "")-\(imageRevision)")
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
