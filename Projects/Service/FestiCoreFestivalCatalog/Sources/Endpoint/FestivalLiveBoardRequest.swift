import Alamofire
import FestivalDomain
import FestiCoreNetworkInterface

struct FestivalLiveRequest: FestiCoreDataRequest {
  typealias Response = FestivalLiveBoardResponseDTO
  let festivalID: String
  let deviceID: String
  let etag: String?

  var path: String { "api/v1/festivals/\(festivalID)/live" }
  var method: HTTPMethod { .get }
  var headers: HTTPHeaders {
    var headers: HTTPHeaders = ["X-Device-Id": deviceID]
    if let etag { headers.add(name: "If-None-Match", value: etag) }
    return headers
  }
  var maxRetryAttempts: Int { 0 }
  var parameters: (any Encodable & Sendable)? { nil }
}

struct FestivalFlagsRequest: FestiCoreDataRequest {
  typealias Response = FestivalFlagsResponseDTO
  let festivalID: String

  var path: String { "api/v1/festivals/\(festivalID)/flags" }
  var method: HTTPMethod { .get }
  var authorization: FestiCoreAuthorization { .none }
  var parameters: (any Encodable & Sendable)? { nil }
}
