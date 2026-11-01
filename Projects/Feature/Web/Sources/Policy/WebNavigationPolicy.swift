//
//  WebNavigationPolicy.swift
//  Web
//
//  Created by FestiCore on 11/2/26.
//

import Foundation

/// 웹 화면 안에서 허용할 이동. 약관 화면에서 앱을 벗어나거나 https가 아닌 문서를 보여 주지 않는다.
enum WebNavigationPolicy {
  enum Decision: Equatable {
    case allow
    case cancel
    /// 새 창 요청을 취소하고 지금 웹뷰에 대신 연다.
    case loadInPlace(URL)
  }

  static func decide(request url: URL?, isNewWindow: Bool, allowedHost: String?) -> Decision {
    guard let url,
          url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased(),
          let allowedHost = allowedHost?.lowercased(),
          host == allowedHost else { return .cancel }
    return isNewWindow ? .loadInPlace(url) : .allow
  }

  /// main frame 응답이 성공 상태일 때만 문서를 보여 준다.
  static func acceptsResponse(statusCode: Int?, isMainFrame: Bool) -> Bool {
    guard isMainFrame else { return true }
    guard let statusCode else { return true }
    return (200..<300).contains(statusCode)
  }
}
