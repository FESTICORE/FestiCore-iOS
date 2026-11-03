//
//  BearerUseCaseImpl.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Dependencies
import FestiCorePackInterface
import Foundation

public struct BearerUseCaseImpl: BearerUseCaseInterface {
  @Dependency(\.bearerRepository) private var repository
  @Dependency(\.packSyncService) private var packSyncService
  @Dependency(\.uuid) private var uuid
  @Dependency(\.date) private var date

  private let photoEncoder = BearerPhotoEncoder()

  public init() {}

  public func claim(festivalID: String, code: String) async throws -> BearerClaim {
    let normalized = code.uppercased()
    // 서버 코드 형식(I·O·0·1 제외 6자리)이 아니면 시도 횟수를 쓰지 않게 보내지 않는다.
    guard normalized.range(of: "^[A-HJ-NP-Z2-9]{6}$", options: .regularExpression) != nil else {
      throw BearerError.invalidRequest
    }
    return try await repository.claim(festivalID: festivalID, code: normalized)
  }

  public func fetchFestival(festivalID: String) async throws -> BearerFestival {
    guard let cached = try await packSyncService.cachedPack(for: festivalID),
          let pack = try? JSONDecoder().decode(BearerPackDTO.self, from: cached.pack) else {
      return BearerFestival(id: festivalID, name: nil, zones: [])
    }
    return pack.toDomain(festivalID: festivalID)
  }

  public func fetchBoard(flagID: String) async throws -> BearerBoard {
    try await repository.fetchBoard(flagID: flagID)
  }

  public func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile {
    try await repository.updateProfile(flagID: flagID, change: change)
  }

  public func uploadPhoto(flagID: String, imageData: Data) async throws -> BearerFlagPhoto {
    let jpeg = try photoEncoder.encode(imageData)
    return try await repository.uploadPhoto(flagID: flagID, jpegData: jpeg)
  }

  public func makeStatusRequest(_ change: BearerStatusChange) -> BearerStatusRequest {
    BearerStatusRequest(change: change, idempotencyKey: uuid().uuidString.lowercased(), clientAt: date.now)
  }

  public func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus {
    try await repository.sendStatus(flagID: flagID, request: request)
  }

  public func inviteCoBearer(flagID: String) async throws -> BearerInvite {
    try await repository.inviteCoBearer(flagID: flagID)
  }

  public func removeCoBearer(flagID: String, userID: String) async throws {
    try await repository.removeCoBearer(flagID: flagID, userID: userID)
  }
}
