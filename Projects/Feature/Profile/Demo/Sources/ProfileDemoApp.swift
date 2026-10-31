//
//  ProfileDemoApp.swift
//  ProfileDemo
//
//  Created by FestiCore on 10/31/26.
//
//  앱 전체를 빌드하지 않고 마이 화면만 확인하기 위한 단독 실행 앱.
//  로그인하지 않은 상태로 띄우고, 앱처럼 확인 팝업 호스트를 화면 위에 함께 올린다.
//  서비스 조립 없이 미리보기 의존성 맥락으로 띄운다. 화면 레이아웃과 컴포넌트 확인이 목적이다.
//

import ComposableArchitecture
import FestiCoreDesignKit
import Profile
import SwiftUI

@main
struct ProfileDemoApp: App {
  init() {
    PretendardFontFamily.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      ProfileDemoRoot()
    }
  }
}

private struct ProfileDemoRoot: View {
  @State private var store = Store(initialState: ProfileFeature.State()) {
    ProfileFeature()
  } withDependencies: {
    $0.context = .preview
  }

  var body: some View {
    let view = ProfileView(
      store: store,
      profile: nil,
      hasSession: false,
      isLoading: false,
      message: nil
    )
    view.overlay { view.dialogOverlay }
  }
}
