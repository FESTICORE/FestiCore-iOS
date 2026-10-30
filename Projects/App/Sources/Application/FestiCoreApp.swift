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

@main
struct FestiCoreApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      RootView(appDelegate: appDelegate)
    }
  }
}

private struct RootView: View {
  let appDelegate: AppDelegate
  @Environment(\.openURL) private var openURL
  @State private var store = Store(initialState: AppCoordinator.State()) {
    AppCoordinator()
  } withDependencies: {
    $0.continuousClock = ContinuousClock()
    $0.date = .init { Date() }
  }
  @State private var showNotificationSettingsAlert = false
  @State private var notificationSettingsAlertGate = NotificationSettingsAlertGate()

  var body: some View {
    AppCoordinatorView(store: store)
      .onOpenURL { url in
        FeatureOAuthURLHandler.handle(url)
      }
      .task {
        await refreshNotificationPermission()
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        Task { await refreshNotificationPermission() }
      }
      .alert("알림이 꺼져 있어요", isPresented: $showNotificationSettingsAlert) {
        Button("설정 열기") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
          }
        }
        Button("나중에", role: .cancel) {}
      } message: {
        Text("알림을 받으려면 설정에서 알림을 허용해 주세요. 알림 없이도 앱을 사용할 수 있어요.")
      }
  }

}

private extension RootView {
  func refreshNotificationPermission() async {
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
    let result = await appDelegate.requestNotificationPermission()
    if notificationSettingsAlertGate.shouldShow(for: result) {
      showNotificationSettingsAlert = true
    }
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
