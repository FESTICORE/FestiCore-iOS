import FestiCoreNetworkInterface
import Foundation

public typealias FestivalLiveBoardResponseDTO = BaseResponseDTO<FestivalLiveBoardDataDTO>

public struct FestivalLiveBoardDataDTO: Decodable, Sendable {
  public let festivalId: String
  public let activeFlags: [FestivalLiveBoardFlagDTO]
  public let me: FestivalLiveBoardMeDTO?
}

public struct FestivalLiveBoardFlagDTO: Decodable, Sendable {
  public let flagId: String
  public let status: String
  public let zoneId: String?
  public let activity: String?
}

public struct FestivalLiveBoardMeDTO: Decodable, Sendable {
  public let following: [String]
  public let crew: FestivalLiveBoardCrewDTO?
}

public struct FestivalLiveBoardCrewDTO: Decodable, Sendable {
  public let id: String
  public let name: String
  public let members: [FestivalLiveBoardMemberDTO]
}

public struct FestivalLiveBoardMemberDTO: Decodable, Sendable {
  public let userId: String
  public let nickname: String
  public let state: String
  public let zoneId: String?
}

public typealias FestivalFlagsResponseDTO = BaseResponseDTO<FestivalFlagsDataDTO>

public struct FestivalFlagsDataDTO: Decodable, Sendable {
  public let items: [FestivalFlagsFlagDTO]
}

public struct FestivalFlagsFlagDTO: Decodable, Sendable {
  public let id: String
  public let name: String
  public let thumbUrl: String?
}
