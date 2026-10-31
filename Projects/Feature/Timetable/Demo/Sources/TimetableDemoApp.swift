//
//  TimetableDemoApp.swift
//  TimetableDemo
//
//  Created by FestiCore on 10/31/26.
//
//  앱 전체를 빌드하지 않고 타임테이블 화면만 확인하기 위한 단독 실행 앱.
//  선택한 축제의 팩이 없어 미발행 화면이 보인다. 서비스 조립 없이 미리보기 의존성 맥락으로 띄운다.
//  화면 레이아웃과 컴포넌트 확인이 목적이다.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI
import Timetable

@main
struct TimetableDemoApp: App {
  init() {
    PretendardFontFamily.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      TimetableDemoRoot()
    }
  }
}

private struct TimetableDemoRoot: View {
  @State private var store = Store(initialState: TimetableFeature.State(days: [], source: "")) {
    TimetableFeature()
  } withDependencies: {
    $0.context = .preview
  }

  var body: some View {
    TimetableView(store: store)
  }
}
