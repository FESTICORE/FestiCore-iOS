public struct AuthProfile: Sendable, Equatable {
  public let user: AuthUser
  public let currentTermsVersion: String
  /// 계정 기수 모드. 끄면 내가 소유한 깃발이 목록·지도·라이브에서 빠진다.
  public let bearerMode: Bool

  public init(
    user: AuthUser,
    currentTermsVersion: String,
    bearerMode: Bool = false
  ) {
    self.user = user
    self.currentTermsVersion = currentTermsVersion
    self.bearerMode = bearerMode
  }

  public var isEligible: Bool {
    !currentTermsVersion.isEmpty && user.nicknameConfirmed
      && user.termsAcceptedAt != nil && user.termsVersion == currentTermsVersion
  }
}
