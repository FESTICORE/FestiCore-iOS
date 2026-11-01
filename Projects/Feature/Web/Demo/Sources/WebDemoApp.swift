//
//  WebDemoApp.swift
//  WebDemo
//
//  Created by FestiCore on 11/2/26.
//
//  앱 전체를 빌드하지 않고 앱 안 웹 화면만 확인하기 위한 단독 실행 앱.
//  정상 문서와 HTTP 오류 주소를 골라 로딩·실패·다시 시도·뒤로를 확인한다.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI
import Web

@main
struct WebDemoApp: App {
  init() {
    PretendardFontFamily.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      WebDemoView(store: Store(initialState: WebDemoFeature.State()) { WebDemoFeature() })
    }
  }
}

/// 실제 앱의 부모 코디네이터처럼 Web을 띄우고 backToRoot에서 닫는다.
@Reducer
struct WebDemoFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var web: WebFeature.State?
  }

  enum Action {
    case open(title: String, url: URL)
    case web(PresentationAction<WebFeature.Action>)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .open(title, url):
        state.web = WebFeature.State(url: url, title: title)
        return .none
      case .web(.presented(.delegate(.backToRoot))):
        state.web = nil
        return .none
      case .web:
        return .none
      }
    }
    .ifLet(\.$web, action: \.web) { WebFeature() }
  }
}

struct WebDemoView: View {
  @Bindable var store: StoreOf<WebDemoFeature>

  private let samples: [(title: String, url: URL)] = [
    ("정상 문서", URL(string: "https://www.apple.com/legal/")!),
    ("HTTP 404", URL(string: "https://www.apple.com/festicore-not-found")!)
  ]

  var body: some View {
    NavigationStack {
      List(samples, id: \.url) { sample in
        Button(sample.title) { store.send(.open(title: sample.title, url: sample.url)) }
      }
      .navigationTitle("Web 데모")
    }
    .fullScreenCover(item: $store.scope(state: \.web, action: \.web)) { webStore in
      WebView(store: webStore)
    }
  }
}
