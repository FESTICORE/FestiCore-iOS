import AuthDomainInterface

struct AuthProfileResponseDTO: Decodable, Sendable {
  let code: String
  let data: AuthProfileDataDTO
}

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

  var profile: AuthProfile {
    AuthProfile(user: AuthUser(
      id: id, provider: provider, email: email, nickname: nickname,
      nicknameConfirmed: nicknameConfirmed, termsAcceptedAt: termsAcceptedAt,
      termsVersion: termsVersion, pushOptIn: pushOptIn, profileImageURL: profileImageUrl
    ), currentTermsVersion: currentTermsVersion)
  }
}

struct AuthProfileUpdateResponseDTO: Decodable, Sendable {
  let code: String
  let data: AuthUserDTO
}
