//
//  FestivalOfficialNewsRequest.swift
//  FestiCoreFestivalCatalog
//
//  Created by FestiCore on 11/20/26.
//

import Alamofire
import FestivalDomain
import FestiCoreNetworkInterface
import Foundation

/// 서버가 5분마다 받아 둔 축제 공식 인스타그램 최근 게시물. 공개 API라 인증하지 않는다.
struct FestivalOfficialNewsRequest: FestiCoreDataRequest {
  typealias Response = FestivalOfficialNewsResponseDTO
  let festivalID: String

  var path: String { return "api/v1/festivals/\(festivalID)/instagram" }
  var method: HTTPMethod { return .get }
  var authorization: FestiCoreAuthorization { return .none }
  var maxRetryAttempts: Int { return 0 }
  var parameters: (any Encodable & Sendable)? { return nil }
}
