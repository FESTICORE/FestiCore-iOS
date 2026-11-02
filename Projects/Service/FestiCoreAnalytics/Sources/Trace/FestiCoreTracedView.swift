//
//  FestiCoreTracedView.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 11/3/26.
//

import SwiftUI

import Sentry

/// 화면 렌더 구간을 Sentry 트랜잭션으로 감싸는 래퍼.
///
/// Sentry 9.30.1 바이너리는 `SentryTracedView`를 `Sentry` 모듈에 포함한다.
/// Sentry를 여기서만 링크해 앱·Feature는 관측 SDK를 모르게 둔다.
public struct FestiCoreTracedView<Content: View>: View {
  private let name: String
  private let content: () -> Content

  public init(_ name: String, @ViewBuilder content: @escaping () -> Content) {
    self.name = name
    self.content = content
  }

  public var body: some View {
    SentryTracedView(name) {
      content()
    }
  }
}
