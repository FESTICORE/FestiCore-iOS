import FestiCoreNetworkInterface
import Foundation

public typealias FestivalLiveBoardResponseDTO = BaseResponseDTO<FestivalLiveBoardDataDTO>

public struct FestivalLiveBoardDataDTO: Decodable, Sendable {
  public let festivalId: String
  public let activeFlags: [FestivalLiveBoardFlagDTO]
  public let me: FestivalLiveBoardMeDTO?
  public let serverAt: String?
}

public struct FestivalLiveBoardFlagDTO: Decodable, Sendable {
  public let flagId: String
  public let status: String
  public let zoneId: String?
  public let activity: String?
  public let updatedAt: String?
}

public struct FestivalLiveBoardMeDTO: Decodable, Sendable {
  public let following: [String]
  public let crew: FestivalLiveBoardCrewDTO?
  public let pinnedFlagId: String?
}

public struct FestivalLiveBoardCrewDTO: Decodable, Sendable {
  public let id: String
  public let name: String
  public let members: [FestivalLiveBoardMemberDTO]
  public let ownerId: String?
  public let gatherRequest: GatherRequest?
  public let gatherAvailableAt: String?

  public struct GatherRequest: Decodable, Sendable {
    public let zoneId: String?
    public let byUserId: String
    public let at: String
  }
}

public struct FestivalLiveBoardMemberDTO: Decodable, Sendable {
  public let userId: String
  public let nickname: String
  public let state: String?
  public let zoneId: String?
  public let updatedAt: String?
}

public typealias FestivalFlagsResponseDTO = BaseResponseDTO<FestivalFlagsDataDTO>

public struct FestivalFlagsDataDTO: Decodable, Sendable {
  public let items: [FestivalFlagsFlagDTO]
}

public struct FestivalFlagsFlagDTO: Decodable, Sendable {
  public let id: String
  public let name: String
  public let thumbUrl: String?
  public let tags: [String]?

  private enum CodingKeys: String, CodingKey {
    case id, name, thumbUrl, tags
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    thumbUrl = try container.decodeIfPresent(String.self, forKey: .thumbUrl)
    if let values = try? container.decode([TagValue].self, forKey: .tags) {
      tags = values.compactMap(\.value)
    } else {
      tags = nil
    }
  }

  private struct TagValue: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
      value = try? decoder.singleValueContainer().decode(String.self)
    }
  }
}
