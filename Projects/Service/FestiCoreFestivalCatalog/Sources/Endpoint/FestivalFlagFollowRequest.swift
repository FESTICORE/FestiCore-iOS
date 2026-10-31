import Alamofire
import FestivalDomain
import FestiCoreNetworkInterface

struct FestivalFlagFollowRequest: FestiCoreDataRequest {
  typealias Response = FestivalFlagFollowResponseDTO
  let flagID: String
  let following: Bool
  /// 팔로우(PUT)에만 쓰는 멱등 키. 서버는 같은 키의 같은 요청에 저장된 응답을 돌려준다.
  let idempotencyKey: String

  var path: String { "api/v1/flags/\(flagID)/follow" }
  var method: HTTPMethod { following ? .put : .delete }
  var headers: HTTPHeaders {
    following ? ["Idempotency-Key": idempotencyKey] : [:]
  }
  var maxRetryAttempts: Int { 0 }
  var parameters: (any Encodable & Sendable)? { nil }
}
