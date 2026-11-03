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
    if path == "/api/v1/auth" || path.hasPrefix("/api/v1/auth/") { return true }
    // 기수 등록 코드(요청)와 공동 기수 초대 코드(응답)는 권한을 넘기는 값이라 남기지 않는다.
    if path == "/api/v1/bearer/claim" { return true }
    return path.hasPrefix("/api/v1/flags/") && path.hasSuffix("/co-bearers/invite")
  }
}
