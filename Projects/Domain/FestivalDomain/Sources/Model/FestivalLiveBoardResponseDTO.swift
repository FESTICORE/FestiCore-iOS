import Foundation

public struct FestivalLiveBoardResponseDTO: Decodable, Sendable {
  public let code: String
  public let data: Data

  public struct Data: Decodable, Sendable {
    public let festivalId: String
    public let activeFlags: [Flag]
    public let me: Me?

    public struct Flag: Decodable, Sendable {
      public let flagId: String
      public let status: String
      public let zoneId: String?
      public let activity: String?
    }

    public struct Me: Decodable, Sendable {
      public let following: [String]
      public let crew: Crew?
    }

    public struct Crew: Decodable, Sendable {
      public let id: String
      public let name: String
      public let members: [Member]
    }

    public struct Member: Decodable, Sendable {
      public let userId: String
      public let nickname: String
      public let state: String
      public let zoneId: String?
    }
  }
}

public struct FestivalFlagsResponseDTO: Decodable, Sendable {
  public let code: String
  public let data: Data

  public struct Data: Decodable, Sendable {
    public let items: [Flag]

    public struct Flag: Decodable, Sendable {
      public let id: String
      public let name: String
      public let thumbUrl: String?
    }
  }
}
