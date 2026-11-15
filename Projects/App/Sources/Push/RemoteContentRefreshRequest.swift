//
//  RemoteContentRefreshRequest.swift
//  FestiCore
//
//  Created by FestiCore on 11/15/26.
//

import UIKit

@MainActor
final class RemoteContentRefreshRequest: NSObject {
  private var completion: ((UIBackgroundFetchResult) -> Void)?

  init(completion: @escaping (UIBackgroundFetchResult) -> Void) {
    self.completion = completion
  }

  func finish(_ result: UIBackgroundFetchResult) {
    guard let completion else { return }
    self.completion = nil
    completion(result)
  }
}
