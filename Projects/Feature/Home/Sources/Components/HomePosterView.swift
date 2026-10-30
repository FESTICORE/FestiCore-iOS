import FestiCoreSharedUI
import SwiftUI

struct HomePosterView: View {
  let url: URL?
  let imageRevision: Int

  var body: some View {
    FCRemoteImage(url: url)
      .content(.fill)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .id("\(url?.absoluteString ?? "")-\(imageRevision)")
  }
}
