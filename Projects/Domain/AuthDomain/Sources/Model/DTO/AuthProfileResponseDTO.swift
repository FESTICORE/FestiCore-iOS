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
}

typealias AuthProfileUpdateResponseDTO = BaseResponseDTO<AuthUserDTO>
