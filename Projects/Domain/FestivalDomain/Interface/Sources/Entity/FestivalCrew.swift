import Foundation

public struct FestivalCrew: Equatable, Sendable {
  public struct Member: Equatable, Sendable {
    public let userID: String
    public let nickname: String
    public let joinedAt: Date

    public init(userID: String, nickname: String, joinedAt: Date) {
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

  public init(
    id: String, festivalID: String, name: String, ownerID: String,
    members: [Member], inviteCode: String?, inviteExpiresAt: Date?
  ) {
    self.id = id
    self.festivalID = festivalID
    self.name = name
    self.ownerID = ownerID
    self.members = members
    self.inviteCode = inviteCode
    self.inviteExpiresAt = inviteExpiresAt
  }
}

public enum FestivalCrewError: Error, Equatable, Sendable {
  case invalidInput
  case unauthenticated
  case termsRequired
  case alreadyInCrew
  case festivalEnded
  case invalidResponse
  case unavailable
}
