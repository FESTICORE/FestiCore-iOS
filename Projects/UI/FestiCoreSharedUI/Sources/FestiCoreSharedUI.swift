//
//  FestiCoreSharedUI.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import FestiCoreDesignKit

/// 기능 화면에서 제목과 내용을 함께 배치합니다.
public struct FestiCoreSection<Content: View>: View {
  private let title: String
  private let content: Content

  public init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM12) {
      Text(title)
        .festiCoreFont(.baseHeadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
      content
    }
  }
}
