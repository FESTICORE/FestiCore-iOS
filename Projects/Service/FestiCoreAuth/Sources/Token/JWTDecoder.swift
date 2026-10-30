//
//  JWTDecoder.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import Foundation

/// 서명 검증이 아니라 선제 갱신에 필요한 exp 값만 읽는다.
enum JWTDecoder {
  static func decodeExpiration(_ token: String) -> Date? {
    guard let object = decodePayload(token),
          let expiration = object["exp"] as? TimeInterval
    else { return nil }
    return Date(timeIntervalSince1970: expiration)
  }

  static func decodeSubject(_ token: String) -> String? {
    guard let subject = decodePayload(token)?["sub"] as? String,
          !subject.isEmpty
    else { return nil }
    return subject
  }

  private static func decodePayload(_ token: String) -> [String: Any]? {
    let segments = token.split(separator: ".")
    guard segments.count > 1 else { return nil }
    var payload = String(segments[1])
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
    guard let data = Data(base64Encoded: payload),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return object
  }
}
