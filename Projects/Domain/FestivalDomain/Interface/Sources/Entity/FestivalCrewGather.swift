import Foundation

/// 모여 요청을 받은 크루원이 고르는 응답
public enum FestivalCrewGatherResponse: String, CaseIterable, Equatable, Sendable {
  /// 모이는 존으로 가는 중
  case going
  /// 봤다는 확인
  case ack
}

/// 크루원 한 명의 모여 응답. 다시 응답하면 서버가 덮어쓴다.
public struct FestivalCrewGatherReply: Equatable, Sendable {
  public let gatherID: String
  public let userID: String
  public let nickname: String
  public let response: FestivalCrewGatherResponse
  public let respondedAt: Date

  public init(
    gatherID: String,
    userID: String,
    nickname: String,
    response: FestivalCrewGatherResponse,
    respondedAt: Date
  ) {
    self.gatherID = gatherID
    self.userID = userID
    self.nickname = nickname
    self.response = response
    self.respondedAt = respondedAt
  }
}
