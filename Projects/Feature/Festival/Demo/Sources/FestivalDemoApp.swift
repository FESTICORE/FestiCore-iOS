//
//  FestivalDemoApp.swift
//  FestivalDemo
//
//  Created by FestiCore on 10/31/26.
//
//  앱 전체를 빌드하지 않고 페스티벌 목록 화면만 확인하기 위한 단독 실행 앱.
//  서비스 조립(ServiceAssembly)을 링크하지 않고 미리보기 의존성 맥락으로 띄운다.
//  카탈로그·팩 서비스는 빈 기본값이라 목록이 비어 보이고, Live Activity와 저장소는 Demo 앱 자신의 샌드박스에서 동작한다.
//  화면 레이아웃과 컴포넌트 확인이 목적이다.
//

import ComposableArchitecture
import Festival
import FestiCoreDesignKit
import SwiftUI

@main
struct FestivalDemoApp: App {
  init() {
    PretendardFontFamily.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      FestivalDemoRoot()
    }
  }
}

private struct FestivalDemoRoot: View {
  @State private var store = Store(initialState: FestivalFeature.State()) {
    FestivalFeature()
  } withDependencies: {
    $0.context = .preview
  }

  var body: some View {
    FestivalView(store: store)
  }
}
