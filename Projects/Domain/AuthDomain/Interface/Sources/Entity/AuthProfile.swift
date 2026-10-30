public struct AuthProfile: Sendable, Equatable {
  public let user: AuthUser
  public let currentTermsVersion: String

  public init(user: AuthUser, currentTermsVersion: String) {
    self.user = user
    self.currentTermsVersion = currentTermsVersion
  }

  public var isEligible: Bool {
    !currentTermsVersion.isEmpty && user.nicknameConfirmed
      && user.termsAcceptedAt != nil && user.termsVersion == currentTermsVersion
  }
}
