import Alamofire
import FestivalDomain
import FestiCoreNetworkInterface

struct FestivalListRequest: FestiCoreDataRequest {
  typealias Response = FestivalListResponseDTO
  let after: String?

  var path: String { "api/v1/festivals" }
  var method: HTTPMethod { .get }
  var authorization: FestiCoreAuthorization { .none }
  var parameters: (any Encodable & Sendable)? { FestivalListParameters(after: after, limit: 50) }
}

private struct FestivalListParameters: Encodable, Sendable {
  let after: String?
  let limit: Int
}
