//
//  BearerRepositoryImpl.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import APIEndpoint
import BearerDomainInterface
import Dependencies
import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreNetwork
import FestiCoreNetworkInterface
import Foundation

public struct BearerRepositoryImpl: BearerRepositoryInterface {
  @Dependency(\.networkClient) private var client
  @Dependency(\.authService) private var authService
  @Dependency(\.deviceRegistrationService) private var deviceService

  /// 서버가 내려 주는 상대 사진 경로를 풀 API 호스트
  private let baseURL: URL?

  public init(baseURL: URL? = NetworkClientFactory.bundleBaseURL) {
    self.baseURL = baseURL
  }

  /// - Parameter code: UseCase가 대문자로 맞추고 형식을 확인한 코드
  public func claim(festivalID: String, code: String) async throws -> BearerClaim {
    let sessionID = try await authenticatedSessionID()
    let deviceID: String
    do {
      deviceID = try await deviceService.installationDeviceID()
    } catch {
      throw BearerError.unavailable
    }
    let request = FlagRequest.claim(
      body: BearerClaimBody(festivalId: festivalID, code: code),
      deviceID: deviceID,
      sessionID: sessionID
    )
    let response: FestiCoreHTTPResponse
    do {
      response = try await client.sendResponse(request)
    } catch {
      throw Self.map(error)
    }
    // 잠금 남은 시간(`data.retryAfter`)을 읽으려고 원시 응답을 직접 해석한다.
    guard (200 ..< 300).contains(response.statusCode) else {
      let body = try? JSONDecoder().decode(BearerErrorBodyDTO.self, from: response.data)
      throw Self.map(ResponseError(httpStatus: response.statusCode, code: body?.code), detail: body?.data)
    }
    guard let decoded = try? JSONDecoder().decode(BearerClaimResponseDTO.self, from: response.data) else {
      throw BearerError.invalidResponse
    }
    return decoded.data.toDomain(baseURL: baseURL)
  }

  public func register(_ request: BearerRegisterRequest) async throws -> BearerClaim {
    let sessionID = try await authenticatedSessionID()
    let response = try await send(
      FlagRequest.register(
        body: request.body,
        idempotencyKey: request.idempotencyKey,
        sessionID: sessionID
      ),
      as: BearerClaimResponseDTO.self
    )
    return response.data.toDomain(baseURL: baseURL)
  }

  public func fetchBearerFlags(festivalID: String?) async throws -> [BearerOwnedFlag] {
    let sessionID = try await authenticatedSessionID()
    let response = try await send(
      FlagRequest.bearerFlags(
        query: BearerFlagsQuery(festivalId: festivalID),
        sessionID: sessionID
      ),
      as: BearerFlagsResponseDTO.self
    )
    return response.data.items.map { $0.toDomain(baseURL: baseURL) }
  }

  public func fetchPinnedFlag() async throws -> BearerPinnedFlag? {
    let sessionID = try await authenticatedSessionID()
    let response = try await send(
      FlagRequest.pinnedFlag(sessionID: sessionID),
      as: BearerPinnedFlagResponseDTO.self
    )
    return response.data.toDomain(baseURL: baseURL)
  }

  public func fetchBoard(flagID: String) async throws -> BearerBoard {
    let sessionID = try await authenticatedSessionID()
    let response = try await send(FlagRequest.bearer(flagID: flagID, sessionID: sessionID), as: BearerBoardResponseDTO.self)
    return try response.data.toDomain(baseURL: baseURL)
  }

  public func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile {
    let sessionID = try await authenticatedSessionID()
    let response = try await send(
      FlagRequest.updateProfile(flagID: flagID, body: change.body, sessionID: sessionID),
      as: BearerProfileResponseDTO.self
    )
    return response.data.toDomain(baseURL: baseURL)
  }

  public func uploadPhoto(
    flagID: String,
    jpegData: Data,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> BearerFlagPhoto {
    let sessionID = try await authenticatedSessionID()
    let request = FlagPhotoUploadRequest<BearerPhotoResponseDTO>(flagID: flagID, imageData: jpegData, sessionID: sessionID)
    do {
      let response = try await client.upload(request, progress: progress)
      return BearerFlagPhoto(
        photoURL: BearerImageURL.resolve(response.data.photoUrl, baseURL: baseURL),
        thumbnailURL: BearerImageURL.resolve(response.data.thumbUrl, baseURL: baseURL)
      )
    } catch {
      throw Self.map(error)
    }
  }

  public func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus {
    let sessionID = try await authenticatedSessionID()
    let response = try await send(
      FlagRequest.status(flagID: flagID, body: request.body, idempotencyKey: request.idempotencyKey, sessionID: sessionID),
      as: BearerStatusResponseDTO.self
    )
    return try response.data.toDomain()
  }

  public func inviteCoBearer(flagID: String) async throws -> BearerInvite {
    let sessionID = try await authenticatedSessionID()
    let response = try await send(
      FlagRequest.inviteCoBearer(flagID: flagID, sessionID: sessionID),
      as: BearerInviteResponseDTO.self
    )
    return try response.data.toDomain()
  }

  public func removeCoBearer(flagID: String, userID: String) async throws {
    let sessionID = try await authenticatedSessionID()
    _ = try await send(
      FlagRequest.removeCoBearer(flagID: flagID, userID: userID, sessionID: sessionID),
      as: FestiCoreEmptyResponse.self
    )
  }
}

private extension BearerRepositoryImpl {
  func authenticatedSessionID() async throws -> UUID {
    guard let sessionID = await authService.authenticatedSessionID else {
      throw BearerError.notAuthenticated
    }
    return sessionID
  }

  func send<T: Decodable & Sendable>(_ request: FlagRequest, as type: T.Type) async throws -> T {
    do {
      return try await client.send(request, as: type)
    } catch {
      throw Self.map(error)
    }
  }
}

extension BearerRepositoryImpl {
  /// 네트워크 오류를 화면이 구분하는 기수 오류로 바꾼다. 전송 실패는 오프라인으로 본다.
  static func map(_ error: any Error) -> any Error {
    guard let networkError = error as? FestiCoreNetworkError else { return error }
    switch networkError {
    case let .transport(transport):
      if case .cancelled = transport { return CancellationError() }
      return BearerError.offline
    case let .response(response):
      return map(response, detail: nil)
    case .decoding:
      return BearerError.invalidResponse
    case .request:
      return BearerError.unavailable
    }
  }

  static func map(_ response: ResponseError, detail: BearerErrorBodyDTO.Detail?) -> BearerError {
    switch (response.httpStatus, response.code) {
    case (400, _): return .invalidRequest
    case (401, _): return .notAuthenticated
    case (403, "TERMS_REQUIRED"): return .termsRequired
    case (403, "FLAG_NOT_OWNER"): return .notOwner
    case (403, _): return .notBearer
    case (404, "ZONE_NOT_FOUND"): return .zoneNotFound
    case (404, _): return .notFound
    case (409, "FLAG_NAME_TAKEN"): return .nameTaken
    case (409, "STATUS_STALE"): return .stale
    case (409, "FLAG_TRANSITION"), (409, "FLAG_RESTART_REQUIRED"): return .transitionRejected
    case (409, "CO_BEARER_FULL"): return .coBearerFull
    case (409, "BEARER_LIMIT"): return .bearerLimit
    case (409, "FLAG_OWNER_REQUIRED"): return .ownerRequired
    case (409, _): return .conflict
    case (413, _): return .photoTooLarge
    case (415, _): return .unsupportedPhoto
    case (422, _): return .invalidCode(remainingAttempts: detail?.remainingAttempts)
    case (423, _): return .codeLocked(retryAfter: detail?.retryAfter ?? 600)
    case (429, _): return .rateLimited
    default: return .unavailable
    }
  }
}
