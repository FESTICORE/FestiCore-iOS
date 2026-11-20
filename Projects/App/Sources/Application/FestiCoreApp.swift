//
//  FestiCoreApp.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import SwiftUI
import UIKit
import ComposableArchitecture

import FeatureAssembly
import FestiCoreAnalytics
import FestiCoreStorageInterface
import FestivalDomainInterface
import FestiCoreUtility

@main
struct FestiCoreApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
        FestiCoreTracedView("AppRoot") {
          RootView(appDelegate: appDelegate)
        }
      } else {
        // 앱 호스트 테스트에서 실제 시작 효과가 다른 테스트의 이슈로 기록되지 않게 한다.
        Color.clear
      }
    }
  }
}

private struct RootView: View {
  let appDelegate: AppDelegate
  @State private var store = Store(initialState: AppCoordinator.State()) {
    AppCoordinator()
  } withDependencies: {
    $0.continuousClock = ContinuousClock()
    $0.date = .init { Date() }
    #if DEBUG
    FestivalPackUITestFixture.configure(&$0)
    OnboardingUITestFixture.configure(&$0)
    #endif
  }
  /// 마이 > 화면 모드(Figma S13-J)
  @SharedReader(.appearanceMode) private var storedAppearanceMode

  var body: some View {
    AppCoordinatorView(store: store)
      .preferredColorScheme(AppearanceMode(storedValue: storedAppearanceMode).colorScheme)
      .onOpenURL { url in
        // festicore:// 딥링크가 아니면 OAuth 콜백으로 넘긴다.
        if !AppDeeplinkBridge.handleURL(url) {
          FeatureOAuthURLHandler.handle(url)
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: .festiCoreDeeplink)) { _ in
        store.send(.view(.deeplinkReceived))
      }
      .onChange(of: store.state.animationID) { _, _ in
        Task { await refreshNotificationPermission() }
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        Task { await refreshNotificationPermission() }
      }
      .onAppear {
        appDelegate.remoteContentHandler = { request in
          let task = store.send(.view(.remoteContentChanged))
          Task { @MainActor in
            await task.finish()
            request.finish(.newData)
          }
        }
      }
      .onDisappear {
        appDelegate.remoteContentHandler = nil
      }
  }
}

private extension RootView {
  /// 홈일 때만 권한 결과를 홈에 넘긴다. 중복 요청은 진행 중인 권한 요청 Task를 재사용해 막는다.
  func refreshNotificationPermission() async {
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
          store.state.animationID == "home" else { return }
    let result = await appDelegate.requestNotificationPermission()
    store.send(.view(.notificationPermissionResolved(result)))
  }
}

#if DEBUG
/// UI 테스트에서 목록·팩을 고정해 서버 데이터와 이전 실행의 다운로드 캐시를 분리한다.
private enum FestivalPackUITestFixture {
  static func configure(_ dependencies: inout DependencyValues) {
    guard ProcessInfo.processInfo.environment["FESTICORE_PACK_UI_TEST"] == "1" else { return }
    let festival = FestivalCatalogItem(
      id: "ui-test-festival",
      name: "UI 테스트 페스티벌",
      firstDate: "2099-11-21",
      packVersion: 1
    )
    let packData = Data(#"{"id":"ui-test-festival","name":"UI 테스트 페스티벌"}"#.utf8)
    dependencies.festivalCatalogUseCase = MockFestivalCatalogUseCase(
      cachedFestivals: { [festival] },
      refreshFestivals: { [festival] },
      festivalDetail: { _ in
        return try JSONDecoder().decode(
          FestivalPackDocument.self,
          from: packData
        )
      },
      savedFestivalID: { nil },
      saveSelectedFestivalID: { _ in }
    )
    dependencies.festivalPackUseCase = MockFestivalPackUseCase(
      cachedPacks: { [] },
      packUpdates: { _ in AsyncThrowingStream { $0.finish() } },
      downloadPack: { id in
        return AsyncThrowingStream { continuation in
          continuation.yield(.finished(.updated(.init(
            festivalID: id,
            packVersion: 1,
            etag: "ui-test-v1",
            pack: packData
          ))))
          continuation.finish()
        }
      }
    )
    dependencies.festivalLiveBoardUseCase = MockFestivalLiveBoardUseCase(liveBoard: { _ in
      throw FestivalLiveBoardError.festivalNotFound
    })
  }
}

/// UI 테스트에서 설치 기록과 상관없이 첫 실행 온보딩부터 보이게 한다. 완료 기록도 남기지 않는다.
private enum OnboardingUITestFixture {
  static func configure(_ dependencies: inout DependencyValues) {
    guard ProcessInfo.processInfo.environment["FESTICORE_ONBOARDING_UI_TEST"] == "1" else { return }
    dependencies.firstInstallOnboardingStore = FirstInstallOnboardingStore(
      hasCompleted: { return false },
      markCompleted: {}
    )
  }
}
#endif
