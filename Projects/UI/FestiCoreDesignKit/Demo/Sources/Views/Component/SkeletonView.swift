//
//  SkeletonView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct SkeletonView: View {
  @State private var isLoading = true

  var body: some View {
    DemoPage("Skeleton 검증") {
      DemoSection("Shape (rect · round · circle)") {
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          FCSkeletonView(.rect)
            .frame(width: 80, height: 56)
          FCSkeletonView(.round())
            .frame(width: 80, height: 56)
          FCSkeletonView(.circle)
            .frame(width: 56, height: 56)
        }
      }
      DemoSection("Modifier (탭해서 전환)") {
        Text("원더리벳 2026")
          .festiCoreFont(.baseBodyBold)
          .skeleton(
            isLoading: isLoading,
            shape: .round(cornerRadius: FestiCoreRadius.r4),
            width: 160,
            height: 24
          )
        FCButton(isLoading ? "불러오기 완료" : "다시 불러오기") {
          isLoading.toggle()
        }
        .size(.medium)
      }
    }
  }
}

#Preview {
  NavigationStack {
    SkeletonView()
  }
}
