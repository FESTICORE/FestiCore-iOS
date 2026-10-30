//
//  MediaBrandView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct MediaBrandView: View {
  var body: some View {
    DemoPage("09 Media & Brand 검증") {
      DemoSection("Avatar (9색)") {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: FestiCoreSpacing.paddingP12) {
            ForEach(FCAvatar.Tint.allCases, id: \.self) { tint in
              FCAvatar("민").tint(tint)
            }
          }
        }
      }
      DemoSection("Thumbnail (empty · filled)") {
        HStack(spacing: FestiCoreSpacing.paddingP16) {
          FCThumbnail(nil)
          FCThumbnail(Image(systemName: "photo"))
        }
      }
      DemoSection("Logo") {
        Image(asset: .logo)
          .resizable()
          .scaledToFit()
          .frame(height: 24)
      }
    }
  }
}

#Preview {
  NavigationStack {
    MediaBrandView()
  }
}
