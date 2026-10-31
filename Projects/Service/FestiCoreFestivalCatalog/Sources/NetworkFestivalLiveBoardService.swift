import FestiCoreDeviceInterface
import FestiCoreAuthInterface
import FestivalDomain
import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation

public actor NetworkFestivalLiveBoardService: FestivalLiveBoardService {
  private struct CachedBoard {
    let etag: String?
    let data: FestivalLiveBoardDataDTO
  }

  private let client: any FestiCoreRequestClient
  private let auth: any AuthService
  private let device: any DeviceRegistrationService
  private let imageResolver: FestivalImageURLResolver
  private let now: @Sendable () -> Date
  private var cachedBoards: [String: CachedBoard] = [:]
  private var retryNotBefore: [String: Date] = [:]
  private var cachedSessionID: UUID?

  public init(
    client: any FestiCoreRequestClient,
    auth: any AuthService,
    device: any DeviceRegistrationService,
    baseURL: URL?,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.client = client
    self.auth = auth
    self.device = device
    imageResolver = FestivalImageURLResolver(baseURL: baseURL)
    self.now = now
  }

  public func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    guard !festivalID.isEmpty,
          festivalID.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
            || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 }) else {
      throw FestivalLiveBoardError.invalidFestivalID
    }
    let deviceID = try await device.installationDeviceID()
    let sessionID = await auth.authenticatedSessionID
    if cachedSessionID != sessionID {
      cachedBoards.removeAll()
      retryNotBefore.removeAll()
      cachedSessionID = sessionID
    }
    if let retryDate = retryNotBefore[festivalID], retryDate > Date() {
      throw FestivalLiveBoardError.rateLimited(retryAfter: retryDate.timeIntervalSinceNow)
    }

    let response = try await client.sendResponse(FestivalLiveRequest(
      festivalID: festivalID,
      deviceID: deviceID,
      etag: sessionID == nil ? nil : cachedBoards[festivalID]?.etag,
      authorization: sessionID == nil ? .none : .automatic
    ))
    let boardData = try decodeBoardData(response, festivalID: festivalID, sessionID: sessionID)
    // 라이브 상태를 확인한 시각이다. 공개 프로필 요청이 오래 걸려도 그 뒤로 미루지 않는다.
    let receivedAt = now()

    let profilesResponse: FestivalFlagsResponseDTO
    do {
      profilesResponse = try await client.send(FestivalFlagsRequest(festivalID: festivalID))
    } catch FestiCoreNetworkError.decoding {
      throw FestivalLiveBoardError.invalidResponse
    }
    guard profilesResponse.code == "SUCCESS" else { throw FestivalLiveBoardError.invalidResponse }
    let snapshot = try boardData.toDomain(
      profiles: profilesResponse.data,
      imageURL: imageResolver.resolve,
      receivedAt: receivedAt
    )
    let latestSessionID = await auth.authenticatedSessionID
    guard cachedSessionID == sessionID, latestSessionID == sessionID else {
      throw FestivalLiveBoardError.invalidResponse
    }
    if sessionID != nil {
      cachedBoards[festivalID] = CachedBoard(
        etag: response.statusCode == 304 ? cachedBoards[festivalID]?.etag : response.header("ETag"),
        data: boardData
      )
    }
    retryNotBefore[festivalID] = nil
    return snapshot
  }

  private func decodeBoardData(
    _ response: FestiCoreHTTPResponse, festivalID: String, sessionID: UUID?
  ) throws -> FestivalLiveBoardDataDTO {
    if (try? JSONDecoder().decode(LiveBoardErrorDTO.self, from: response.data))?.code == "FESTIVAL_NOT_FOUND" {
      cachedBoards[festivalID] = nil
      throw FestivalLiveBoardError.festivalNotFound
    }
    switch response.statusCode {
    case 200:
      let boardResponse = try JSONDecoder().decode(FestivalLiveBoardResponseDTO.self, from: response.data)
      guard boardResponse.code == "SUCCESS", boardResponse.data.festivalId == festivalID else {
        throw FestivalLiveBoardError.invalidResponse
      }
      return boardResponse.data
    case 304:
      guard sessionID != nil, let cached = cachedBoards[festivalID] else {
        throw FestivalLiveBoardError.invalidResponse
      }
      return cached.data
    case 401:
      let error = try? JSONDecoder().decode(LiveBoardErrorDTO.self, from: response.data)
      throw FestiCoreNetworkError.response(ResponseError(
        httpStatus: 401, code: error?.code, message: error?.message
      ))
    case 429:
      let retryAfter = Self.retryAfter(response.header("Retry-After"))
      retryNotBefore[festivalID] = Date().addingTimeInterval(retryAfter)
      throw FestivalLiveBoardError.rateLimited(retryAfter: retryAfter)
    default:
      throw FestivalLiveBoardError.invalidResponse
    }
  }

  private static func retryAfter(_ value: String?) -> TimeInterval {
    guard let value, let seconds = TimeInterval(value), seconds.isFinite else { return 35 }
    return max(seconds, 1)
  }
}

private struct LiveBoardErrorDTO: Decodable {
  let code: String?
  let message: String?
}
