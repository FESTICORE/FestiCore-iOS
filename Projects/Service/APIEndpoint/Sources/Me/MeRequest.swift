//
//  MeRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 10/29/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface

public enum MeRequest: FestiCoreDataRequest, Sendable {
  case withdraw

  public var path: String { MeAPI.me.path }
  public var method: HTTPMethod { .delete }
  public var authorization: FestiCoreAuthorization { .automatic }
  public var maxRetryAttempts: Int { 0 }
}
