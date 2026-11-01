import FestiCoreNetworkInterface
import Foundation

public typealias FestivalListResponseDTO = BaseResponseDTO<FestivalListDataDTO>

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
  public let ticketLinks: FestivalTicketLinksDTO?
}

public struct FestivalTicketLinkDTO: Codable, Sendable, Equatable {
  public let label: String
  public let url: String
}

/// 원소 하나가 깨져도 나머지 링크와 축제 항목은 살린다.
public struct FestivalTicketLinksDTO: Codable, Sendable, Equatable {
  public let items: [FestivalTicketLinkDTO]

  public init(items: [FestivalTicketLinkDTO]) {
    self.items = items
  }

  public init(from decoder: Decoder) throws {
    guard var container = try? decoder.unkeyedContainer() else {
      items = []
      return
    }
    var result: [FestivalTicketLinkDTO] = []
    while !container.isAtEnd {
      if (try? container.decodeNil()) == true { continue }
      if let link = try? container.decode(FestivalTicketLinkDTO.self) {
        result.append(link)
      } else {
        _ = try? container.decode(Skipped.self)
      }
    }
    items = result
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(items)
  }

  private struct Skipped: Decodable {
    init(from decoder: Decoder) throws {}
  }
}
