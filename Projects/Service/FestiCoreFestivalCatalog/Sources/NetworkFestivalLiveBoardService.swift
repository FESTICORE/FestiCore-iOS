import Alamofire
import FestiCoreDeviceInterface
import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation

public enum FestivalLiveBoardError: Error, Sendable {
  case deviceNotRegistered
  case invalidFestivalID
  case invalidResponse
}

public actor NetworkFestivalLiveBoardService: FestivalLiveBoardService {
  private let client: any FestiCoreRequestClient
  private let device: any DeviceRegistrationService
  private let imageResolver: FestivalImageURLResolver

  public init(
    client: any FestiCoreRequestClient,
    device: any DeviceRegistrationService,
    baseURL: URL?
  ) {
    self.client = client
    self.device = device
    imageResolver = FestivalImageURLResolver(baseURL: baseURL)
  }

  public func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    guard !festivalID.isEmpty,
          festivalID.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
            || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 }) else {
      throw FestivalLiveBoardError.invalidFestivalID
    }
    guard let deviceID = try await device.authorization()?.deviceID else {
      throw FestivalLiveBoardError.deviceNotRegistered
    }
    async let board = client.send(FestivalLiveRequest(festivalID: festivalID, deviceID: deviceID))
    async let profiles = client.send(FestivalFlagsRequest(festivalID: festivalID))
    let (boardResponse, profilesResponse) = try await (board, profiles)
    guard boardResponse.code == "SUCCESS", profilesResponse.code == "SUCCESS",
          boardResponse.data.festivalId == festivalID else {
      throw FestivalLiveBoardError.invalidResponse
    }
    let profileByID = Dictionary(
      profilesResponse.data.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )
    let activeFlags = boardResponse.data.activeFlags.map { flag in
      makeFlag(flag, profile: profileByID[flag.flagId])
    }
    let activeByID = Dictionary(activeFlags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let followedFlags = (boardResponse.data.me?.following ?? []).map { id in
      activeByID[id] ?? makeFlag(nil, id: id, profile: profileByID[id])
    }
    let crew = boardResponse.data.me?.crew.map { crew in
      FestivalLiveBoardSnapshot.Crew(
        id: crew.id,
        name: crew.name,
        members: crew.members.map {
          .init(id: $0.userId, nickname: $0.nickname, state: $0.state, zoneID: $0.zoneId)
        }
      )
    }
    return .init(festivalID: festivalID, activeFlags: activeFlags, followedFlags: followedFlags, crew: crew)
  }

  private func makeFlag(
    _ status: LiveBoardResponse.Data.Flag?,
    id: String? = nil,
    profile: FlagsResponse.Data.Flag?
  ) -> FestivalLiveBoardSnapshot.Flag {
    .init(
      id: status?.flagId ?? id ?? "",
      name: profile?.name ?? status?.flagId ?? id ?? "깃발",
      status: status?.status ?? "unknown",
      zoneID: status?.zoneId,
      activity: status?.activity,
      thumbnailURL: imageResolver.resolve(profile?.thumbUrl)
    )
  }
}

private struct FestivalLiveRequest: FestiCoreDataRequest {
  typealias Response = LiveBoardResponse
  let festivalID: String
  let deviceID: String

  var path: String { "api/v1/festivals/\(festivalID)/live" }
  var method: HTTPMethod { .get }
  var headers: HTTPHeaders { ["X-Device-Id": deviceID] }
  var maxRetryAttempts: Int { 0 }
  var parameters: (any Encodable & Sendable)? { nil }
}

private struct FestivalFlagsRequest: FestiCoreDataRequest {
  typealias Response = FlagsResponse
  let festivalID: String

  var path: String { "api/v1/festivals/\(festivalID)/flags" }
  var method: HTTPMethod { .get }
  var authorization: FestiCoreAuthorization { .none }
  var parameters: (any Encodable & Sendable)? { nil }
}

private struct LiveBoardResponse: Decodable, Sendable {
  let code: String
  let data: Data

  struct Data: Decodable, Sendable {
    let festivalId: String
    let activeFlags: [Flag]
    let me: Me?

    struct Flag: Decodable, Sendable {
      let flagId: String
      let status: String
      let zoneId: String?
      let activity: String?
    }

    struct Me: Decodable, Sendable {
      let following: [String]
      let crew: Crew?
    }

    struct Crew: Decodable, Sendable {
      let id: String
      let name: String
      let members: [Member]
    }

    struct Member: Decodable, Sendable {
      let userId: String
      let nickname: String
      let state: String
      let zoneId: String?
    }
  }
}

private struct FlagsResponse: Decodable, Sendable {
  let code: String
  let data: Data

  struct Data: Decodable, Sendable {
    let items: [Flag]

    struct Flag: Decodable, Sendable {
      let id: String
      let name: String
      let thumbUrl: String?
    }
  }
}
