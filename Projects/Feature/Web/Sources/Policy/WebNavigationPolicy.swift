//
//  WebNavigationPolicy.swift
//  Web
//
//  Created by FestiCore on 11/2/26.
//

import Foundation

/// 웹 화면이 허용하는 이동 범위.
public enum WebNavigationScope: Equatable, Sendable {
  /// 약관 같은 문서. 처음 연 주소와 같은 호스트의 https 문서만 보여 준다.
  case document
  /// 티켓 예매. 다른 호스트의 http·https 이동을 허용하고, 카드사·간편결제·App Store 같은 앱 스킴은 외부 앱으로 넘긴다.
  case booking
}

/// 웹 화면 안에서 허용할 이동.
enum WebNavigationPolicy {
  enum Decision: Equatable {
    case allow
    case cancel
    /// 새 창 요청을 취소하고 지금 웹뷰에 대신 연다.
    case loadInPlace(URL)
    /// 웹뷰에서 열지 않고 외부 앱으로 넘긴다.
    case openExternally(URL)
  }

  /// WebKit이 문서 안에서 직접 다루는 스킴. 예매 화면의 iframe·스크립트가 쓴다.
  private static let inlineSchemes: Set<String> = ["about", "blob", "data"]

  static func decide(
    request url: URL?,
    isNewWindow: Bool,
    allowedHost: String?,
    scope: WebNavigationScope = .document
  ) -> Decision {
    switch scope {
    case .document:
      return decideDocument(
        request: url,
        isNewWindow: isNewWindow,
        allowedHost: allowedHost
      )
    case .booking:
      return decideBooking(
        request: url,
        isNewWindow: isNewWindow
      )
    }
  }

  /// main frame 응답은 HTTP 상태가 200..<300일 때만 문서로 보여 준다. 상태가 없는 응답도 거절한다.
  static func acceptsResponse(
    statusCode: Int?,
    isMainFrame: Bool
  ) -> Bool {
    guard isMainFrame else { return true }
    guard let statusCode else { return false }
    return (200..<300).contains(statusCode)
  }
}

private extension WebNavigationPolicy {
  static func decideDocument(
    request url: URL?,
    isNewWindow: Bool,
    allowedHost: String?
  ) -> Decision {
    guard let url,
          url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased(),
          let allowedHost = allowedHost?.lowercased(),
          host == allowedHost else { return .cancel }
    return isNewWindow ? .loadInPlace(url) : .allow
  }

  static func decideBooking(
    request url: URL?,
    isNewWindow: Bool
  ) -> Decision {
    guard let url, let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return .cancel }
    if scheme == "https" || scheme == "http" {
      guard url.host?.isEmpty == false else { return .cancel }
      return isNewWindow ? .loadInPlace(url) : .allow
    }
    if inlineSchemes.contains(scheme) {
      return isNewWindow ? .cancel : .allow
    }
    return .openExternally(url)
  }
}
