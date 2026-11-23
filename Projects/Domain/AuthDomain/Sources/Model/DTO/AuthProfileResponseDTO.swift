import FestiCoreNetworkInterface

typealias AuthProfileResponseDTO = BaseResponseDTO<AuthProfileDataDTO>

struct AuthProfileDataDTO: Decodable, Sendable {
  let id: String
  let provider: String
  let email: String?
  let nickname: String?
  let nicknameConfirmed: Bool
  let termsAcceptedAt: String?
  let termsVersion: String?
  let pushOptIn: Bool
  let profileImageUrl: String?
  let currentTermsVersion: String
  /// 예전 서버 응답에는 없을 수 있다. 없으면 꺼진 것으로 본다.
  let bearerMode: Bool?
}

typealias AuthBearerModeResponseDTO = BaseResponseDTO<AuthBearerModeDataDTO>

struct AuthBearerModeDataDTO: Decodable, Sendable {
  let bearerMode: Bool
}

typealias AuthProfileUpdateResponseDTO = BaseResponseDTO<AuthUserDTO>
