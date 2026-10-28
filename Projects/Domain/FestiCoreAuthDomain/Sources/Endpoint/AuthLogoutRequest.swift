//
//  AuthLogoutRequest.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import Alamofire
import FestiCoreNetworkInterface

struct AuthLogoutRequest: FestiCoreDataRequest {
  typealias Response = AuthLogoutResponseDTO

  var path: String { "api/v1/auth/logout" }
  var method: HTTPMethod { .post }
  var authorization: FestiCoreAuthorization { .automatic }
  var maxRetryAttempts: Int { 0 }
}
