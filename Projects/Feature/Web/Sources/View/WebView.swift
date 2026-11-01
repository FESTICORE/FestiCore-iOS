//
//  WebView.swift
//  Web
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// 약관 같은 문서를 앱 안에서 보여 준다. 웹뷰는 항상 붙여 두고 로딩·실패 중에는 덮개로 가린다.
@ViewAction(for: WebFeature.self)
public struct WebView: View {
  @Bindable public var store: StoreOf<WebFeature>

  public init(store: StoreOf<WebFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: store.title)
        .onBack { send(.closeTapped) }
      ZStack {
        webContent
        overlay
      }
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .task { send(.onAppear) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(WebAccessibilityID.root)
  }
}

private extension WebView {
  var webContent: some View {
    WebRepresentableView(
      url: store.url,
      loadID: store.loadID,
      onFinished: { send(.loadFinished(loadID: $0)) },
      onFailed: { send(.loadFailed(loadID: $0)) }
    )
    .allowsHitTesting(store.phase == .loaded)
    .accessibilityHidden(store.phase != .loaded)
  }

  @ViewBuilder
  var overlay: some View {
    switch store.phase {
    case .loaded:
      EmptyView()
    case .loading:
      ZStack {
        FestiCoreSemanticColor.backgroundNormal.color
        ProgressView()
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("문서를 불러오는 중")
      .accessibilityIdentifier(WebAccessibilityID.loading)
    case .failed:
      ZStack(alignment: .top) {
        FestiCoreSemanticColor.backgroundNormal.color
        FCEmptyCard(
          icon: .circleInfo16,
          title: "문서를 불러오지 못했어요",
          message: "연결을 확인하고 다시 시도해 주세요."
        )
        .action(FCCardAction("다시 시도") { send(.retryTapped) })
        .padding(FestiCoreSpacing.paddingP16)
      }
      .accessibilityIdentifier(WebAccessibilityID.failure)
    }
  }
}
