//
//  NetworkLogRedactor.swift
//  FestiCoreNetwork
//
//  Created by FestiCore on 10/29/26.
//

import Foundation

enum NetworkLogRedactor {
  static func headers(_ headers: [String: String]) -> [String: String] {
    headers.reduce(into: [:]) { result, header in
      let key = header.key.lowercased()
      result[header.key] = switch key {
      case "authorization", "cookie", "set-cookie", "x-api-key": "<redacted>"
      default: header.value
      }
    }
  }

  static func hidesBody(for url: URL?) -> Bool {
    guard let path = url?.path.lowercased() else { return false }
    return path == "/api/v1/auth" || path.hasPrefix("/api/v1/auth/")
  }
}
