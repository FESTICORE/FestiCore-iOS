import Foundation

public struct FestivalCrew: Equatable, Sendable {
  public struct Member: Equatable, Sendable {
    public let userID: String
    public let nickname: String
    public let joinedAt: Date

    public init(
      userID: String,
      nickname: String,
      joinedAt: Date
    ) {
      self.userID = userID
      self.nickname = nickname
      self.joinedAt = joinedAt
    }
  }

  public let id: String
  public let festivalID: String
  public let name: String
  public let ownerID: String
  public let members: [Member]
  public let inviteCode: String?
  public let inviteExpiresAt: Date?
  /// 크루원 존·상태와 집결 요청. 상세·가입 응답에만 있다.
  public let live: FestivalLiveBoardSnapshot.Crew?
  /// 축제가 끝나 보관된 시각. 보관된 크루는 읽기만 할 수 있다.
  public let archivedAt: Date?

  /// 서버가 받는 크루 최대 인원
  public static let maxMembers = 12
  /// 크루 이름 최대 글자 수. 이전에 만든 13~20자 이름은 조회만 된다.
  public static let maxNameLength = 12

  public init(
    id: String,
    festivalID: String,
    name: String,
    ownerID: String,
    members: [Member],
    inviteCode: String?,
    inviteExpiresAt: Date?,
    live: FestivalLiveBoardSnapshot.Crew? = nil,
    archivedAt: Date? = nil
  ) {
    self.id = id
    self.festivalID = festivalID
    self.name = name
    self.ownerID = ownerID
    self.members = members
    self.inviteCode = inviteCode
    self.inviteExpiresAt = inviteExpiresAt
    self.live = live
    self.archivedAt = archivedAt
  }
}

public enum FestivalCrewError: Error, Equatable, Sendable {
  case invalidInput
  case unauthenticated
  case termsRequired
  case alreadyInCrew
  case festivalEnded
  case invalidResponse
  case forbidden
  case cooldown
  case unavailable
  /// 없거나 만료된 초대 코드
  case notFound
  /// 정원이 찬 크루
  case full
  /// 응답 시간(10분)이 지난 모여
  case gatherExpired
}
