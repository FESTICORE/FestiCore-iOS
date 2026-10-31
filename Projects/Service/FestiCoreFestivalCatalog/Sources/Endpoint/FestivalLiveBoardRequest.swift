import Alamofire
import FestivalDomain
import FestiCoreNetworkInterface
import Foundation

struct FestivalLiveRequest: FestiCoreDataRequest {
  typealias Response = FestivalLiveBoardResponseDTO
  let festivalID: String
  let deviceID: String
  let etag: String?
  let authorization: FestiCoreAuthorization

  var path: String { "api/v1/festivals/\(festivalID)/live" }
  var method: HTTPMethod { .get }
  var headers: HTTPHeaders {
    var headers: HTTPHeaders = ["X-Device-Id": deviceID]
    if let etag { headers.add(name: "If-None-Match", value: etag) }
    return headers
  }
  var cachePolicy: URLRequest.CachePolicy? { .reloadIgnoringLocalCacheData }
  var maxRetryAttempts: Int { 0 }
  var parameters: (any Encodable & Sendable)? { nil }
}

struct FestivalFlagsRequest: FestiCoreDataRequest {
  typealias Response = FestivalFlagsResponseDTO
  let festivalID: String

  var path: String { "api/v1/festivals/\(festivalID)/flags" }
  var method: HTTPMethod { .get }
  var authorization: FestiCoreAuthorization { .none }
  // 팔로우 직후 공개 프로필의 팔로워 수가 이전 URLCache 값으로 되돌아가지 않게 한다.
  var cachePolicy: URLRequest.CachePolicy? { .reloadIgnoringLocalCacheData }
  var parameters: (any Encodable & Sendable)? { nil }
}
