//
//  FeatureOAuthURLHandler.swift
//  FeatureAssembly
//
//  Created by FestiCore on 10/29/26.
//

import FestiCoreAuthDomain
import Foundation

@MainActor
public enum FeatureOAuthURLHandler {
  @discardableResult
  public static func handle(_ url: URL) -> Bool {
    GoogleOAuthURLHandler.handle(url)
  }
}
