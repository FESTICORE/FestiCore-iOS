//
//  GoogleOAuthURLHandler.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Foundation
import GoogleSignIn

@MainActor
public enum GoogleOAuthURLHandler {
  public static func handle(_ url: URL) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
  }
}
