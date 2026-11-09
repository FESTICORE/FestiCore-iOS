//
//  LegalDocumentURL.swift
//  Web
//
//  Created by FestiCore on 11/10/26.
//

import Foundation

/// 약관 문서 기준 주소. 값은 xcconfig의 `FESTICORE_LEGAL_BASE_URL`을 Info.plist `FestiCoreLegalBaseURL`로 받는다.
public enum LegalDocumentURL {
  static let infoPlistKey = "FestiCoreLegalBaseURL"

  /// 앱 Info.plist의 약관 기준 주소. 값이 없거나 호스트가 비어 있으면 nil이다.
  public static var baseURL: URL? {
    return baseURL(infoDictionary: Bundle.main.infoDictionary)
  }

  /// Info.plist 딕셔너리에서 약관 기준 주소를 읽는다.
  static func baseURL(infoDictionary: [String: Any]?) -> URL? {
    guard let value = infoDictionary?[infoPlistKey] as? String,
          let url = URL(string: value),
          url.scheme == "https",
          let host = url.host(),
          !host.isEmpty
    else {
      return nil
    }
    return url
  }
}
