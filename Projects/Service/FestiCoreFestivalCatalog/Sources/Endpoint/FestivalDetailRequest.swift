import Alamofire
import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation

struct FestivalDetailRequest: FestiCoreDataRequest {
  typealias Response = BaseResponseDTO<FestivalPackDocument>
  let festivalID: String

  var path: String { return "api/v1/festivals/\(festivalID)" }
  var method: HTTPMethod { return .get }
  var authorization: FestiCoreAuthorization { return .none }
  var cachePolicy: URLRequest.CachePolicy? { return .reloadIgnoringLocalCacheData }
  var maxRetryAttempts: Int { return 0 }
  var parameters: (any Encodable & Sendable)? { return nil }
}
