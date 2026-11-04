import FestiCoreNetworkInterface
import Foundation

public typealias FestivalCrewResponseDTO = BaseResponseDTO<FestivalCrewDataDTO>

public struct FestivalCrewDataDTO: Decodable, Sendable {
  public struct Member: Decodable, Sendable {
    public let userId: String
    public let nickname: String
    public let joinedAt: String
  }

  public let id: String
  public let festivalId: String
  public let name: String
  public let ownerId: String
  public let members: [Member]
  public let inviteCode: String?
  public let inviteExpiresAt: String?
}
