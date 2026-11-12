//
//  UIKitMapAppClient.swift
//  FestiCoreLocation
//
//  Created by FestiCore on 11/12/26.
//

import FestiCoreLocationInterface
import UIKit

/// `UIApplication.canOpenURL`로 지도 앱 스킴을 확인한다. 스킴이 `LSApplicationQueriesSchemes`에 없으면 항상 false다.
struct UIKitMapAppClient: MapAppClient {
  func isInstalled(_ app: MapApp) async -> Bool {
    guard let url = URL(string: "\(app.rawValue)://") else { return false }
    return await UIApplication.shared.canOpenURL(url)
  }
}
