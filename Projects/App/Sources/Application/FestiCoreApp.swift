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
  @Environment(\.openURL) private var openURL
  @State private var showNotificationSettingsAlert = false
  @State private var hasShownNotificationSettingsAlert = false

  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: AppCoordinator.State()) {
        AppCoordinator()
      } withDependencies: {
        $0.continuousClock = ContinuousClock()
        $0.date = .init { Date() }
      }

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

  private func refreshNotificationPermission() async {
    let result = await appDelegate.requestNotificationPermission()
    if result == .denied && !hasShownNotificationSettingsAlert {
      hasShownNotificationSettingsAlert = true
      showNotificationSettingsAlert = true
    }
  }
}
