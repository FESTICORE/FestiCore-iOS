import Foundation

public struct FestivalListResponseDTO: Decodable, Sendable {
  public let code: String
  public let data: FestivalListDataDTO
}

public struct FestivalListDataDTO: Decodable, Sendable {
  public let items: [FestivalItemDTO]
  public let nextCursor: String?
}

public struct FestivalItemDTO: Codable, Sendable {
  public let id: String
  public let name: String
  public let venue: String?
  public let firstDate: String?
  public let lastDate: String?
  public let thumbUrl: String?
  public let packVersion: Int
  public let status: String?
}
