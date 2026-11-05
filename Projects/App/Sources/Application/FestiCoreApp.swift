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
import FestivalDomainInterface

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
    #endif
  }
  @State private var showNotificationSettingsAlert = false
  @State private var notificationSettingsAlertGate = NotificationSettingsAlertGate()
  @State private var notificationPermissionRefreshGate = NotificationPermissionRefreshGate()
  @State private var pendingWidgetRoute: WidgetDeepLink?

  var body: some View {
    AppCoordinatorView(store: store)
      .preferredColorScheme(.dark)
      .onOpenURL { url in
        if let route = WidgetDeepLink(url: url) {
          pendingWidgetRoute = route
          openPendingWidgetRouteIfReady()
        } else {
          FeatureOAuthURLHandler.handle(url)
        }
      }
      .onChange(of: store.state.animationID) { _, _ in
        openPendingWidgetRouteIfReady()
        Task { await refreshNotificationPermission() }
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        Task { await refreshNotificationPermission() }
      }
      .onReceive(NotificationCenter.default.publisher(for: .festiCoreRemoteContentDidChange)) { notification in
        let request = notification.object as? RemoteContentRefreshRequest
        let task = store.send(.view(.remoteContentChanged))
        Task { @MainActor in
          await task.finish()
          request?.finish(.newData)
        }
      }
      .alert("알림이 꺼져 있어요", isPresented: $showNotificationSettingsAlert) {
        Button("설정 열기") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
        }
        Button("나중에", role: .cancel) {}
      } message: {
        Text("알림을 받으려면 설정에서 알림을 허용해 주세요. 알림 없이도 앱을 사용할 수 있어요.")
      }
  }
}

private extension RootView {
  func openPendingWidgetRouteIfReady() {
    guard store.state.animationID == "home", let route = pendingWidgetRoute else { return }
    pendingWidgetRoute = nil
    store.send(.view(.openWidgetRoute(route)))
  }

  func refreshNotificationPermission() async {
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
          notificationPermissionRefreshGate.beginIfNeeded(
            isHome: store.state.animationID == "home"
          ) else { return }
    defer { notificationPermissionRefreshGate.finish() }
    let result = await appDelegate.requestNotificationPermission()
    if notificationSettingsAlertGate.shouldShow(for: result) {
      showNotificationSettingsAlert = true
    }
  }
}

struct NotificationPermissionRefreshGate {
  private var isRefreshing = false

  mutating func beginIfNeeded(isHome: Bool) -> Bool {
    guard isHome, !isRefreshing else { return false }
    isRefreshing = true
    return true
  }

  mutating func finish() {
    isRefreshing = false
  }
}

struct NotificationSettingsAlertGate {
  private var hasShown = false

  mutating func shouldShow(for result: NotificationPermissionResult) -> Bool {
    guard result == .denied, !hasShown else { return false }
    hasShown = true
    return true
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
#endif
