import Foundation

/// 초대 코드로 미리 본 크루. 로그인 없이 받는 공개 정보만 담는다.
public struct FestivalCrewInvite: Equatable, Sendable {
  /// 먼저 들어온 크루원. 식별 정보 없이 닉네임과 프로필 이미지만 받는다.
  public struct Member: Equatable, Sendable {
    public let nickname: String
    public let avatarURL: URL?

    public init(
      nickname: String,
      avatarURL: URL?
    ) {
      self.nickname = nickname
      self.avatarURL = avatarURL
    }
  }

  public let code: String
  public let crewName: String
  public let festivalID: String
  public let festivalName: String?
  public let inviterNickname: String?
  public let memberCount: Int
  public let expiresAt: Date
  /// 서버가 주는 최대 3명. 이전 서버 응답이면 비어 있다.
  public let memberPreview: [Member]

  public init(
    code: String,
    crewName: String,
    festivalID: String,
    festivalName: String?,
    inviterNickname: String?,
    memberCount: Int,
    expiresAt: Date,
    memberPreview: [Member] = []
  ) {
    self.code = code
    self.crewName = crewName
    self.festivalID = festivalID
    self.festivalName = festivalName
    self.inviterNickname = inviterNickname
    self.memberCount = memberCount
    self.expiresAt = expiresAt
    self.memberPreview = memberPreview
  }
}

/// 크루장이 새로 받은 초대 코드. 이전 코드는 서버에서 바로 무효가 된다.
public struct FestivalCrewInviteCode: Equatable, Sendable {
  public let code: String
  public let expiresAt: Date

  public init(
    code: String,
    expiresAt: Date
  ) {
    self.code = code
    self.expiresAt = expiresAt
  }
}

/// 크루원이 한 번에 공유하는 내 상태
public enum FestivalCrewState: String, CaseIterable, Equatable, Sendable {
  case here
  case eating
  case toilet
  case leaving
}
