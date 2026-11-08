//
//  View+ScrollBottomInset.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 11/8/26.
//

import SwiftUI

public extension View {
  /// Figma: 스크롤 내용은 끝까지 내렸을 때 화면 하단(탭바·홈 인디케이터)에서 20pt 떨어져 멈춘다.
  /// 세로 `ScrollView`에 붙이고, 스크롤 내용 안에는 따로 아래 여백을 두지 않는다.
  func fcScrollBottomInset() -> some View {
    return contentMargins(
      .bottom,
      FestiCoreSpacing.paddingP20,
      for: .scrollContent
    )
  }
}
