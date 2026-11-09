//
//  AuthDomainError+Network.swift
//  AuthDomain
//
//  Created by FestiCore on 11/10/26.
//

import AuthDomainInterface
import FestiCoreNetworkInterface

extension AuthDomainError {
  /// 계정 요청의 네트워크 오류를 앱이 분기하는 도메인 오류로 바꾼다.
  init(_ network: FestiCoreNetworkError) {
    switch network {
    case let .transport(transport):
      switch transport {
      case .notConnected, .timedOut:
        self = .offline
      case .cancelled, .unknown:
        self = .unavailable
      }
    case let .response(response):
      if response.httpStatus == 401 {
        self = .notAuthenticated
      } else if response.httpStatus == 422 && response.code == "TERMS_VERSION_OUTDATED" {
        self = .termsVersionOutdated
      } else {
        self = .unavailable
      }
    case .request, .decoding:
      self = .unavailable
    }
  }

  /// 네트워크 오류만 도메인 오류로 바꾸고 나머지 오류는 그대로 둔다.
  static func mapping(_ error: any Error) -> any Error {
    guard let network = error as? FestiCoreNetworkError else { return error }
    return AuthDomainError(network)
  }
}
