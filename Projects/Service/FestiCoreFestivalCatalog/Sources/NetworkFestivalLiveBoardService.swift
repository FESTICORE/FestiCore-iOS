import Alamofire
import FestiCoreDeviceInterface
import FestivalDomain
import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation

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
    return boardResponse.toEntity(profiles: profilesResponse, imageURL: imageResolver.resolve)
  }
}

private struct FestivalLiveRequest: FestiCoreDataRequest {
  typealias Response = FestivalLiveBoardResponseDTO
  let festivalID: String
  let deviceID: String

  var path: String { "api/v1/festivals/\(festivalID)/live" }
  var method: HTTPMethod { .get }
  var headers: HTTPHeaders { ["X-Device-Id": deviceID] }
  var maxRetryAttempts: Int { 0 }
  var parameters: (any Encodable & Sendable)? { nil }
}

private struct FestivalFlagsRequest: FestiCoreDataRequest {
  typealias Response = FestivalFlagsResponseDTO
  let festivalID: String

  var path: String { "api/v1/festivals/\(festivalID)/flags" }
  var method: HTTPMethod { .get }
  var authorization: FestiCoreAuthorization { .none }
  var parameters: (any Encodable & Sendable)? { nil }
}
