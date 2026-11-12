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
  @Dependency(\.bearerStatusOutbox) private var outbox
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

  public func makeRegisterRequest(
    festivalID: String,
    change: BearerProfileChange
  ) -> BearerRegisterRequest {
    return BearerRegisterRequest(
      festivalID: festivalID,
      change: change,
      idempotencyKey: "register-\(uuid().uuidString.lowercased())"
    )
  }

  public func register(_ request: BearerRegisterRequest) async throws -> BearerClaim {
    return try await repository.register(request)
  }

  public func fetchBearerFlags(festivalID: String?) async throws -> [BearerOwnedFlag] {
    return try await repository.fetchBearerFlags(festivalID: festivalID)
  }

  public func fetchPinnedFlag() async throws -> BearerPinnedFlag? {
    return try await repository.fetchPinnedFlag()
  }

  public func fetchFollowedFlags(festivalID: String?) async throws -> [BearerFollowedFlag] {
    return try await repository.fetchFollowedFlags(festivalID: festivalID)
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

  public func uploadPhoto(flagID: String, imageData: Data) -> AsyncThrowingStream<BearerPhotoUploadEvent, Error> {
    let repository = repository
    let photoEncoder = photoEncoder
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          let jpeg = try photoEncoder.encode(imageData)
          let photo = try await repository.uploadPhoto(flagID: flagID, jpegData: jpeg) { fraction in
            continuation.yield(.progress(min(max(fraction, 0), 1)))
          }
          continuation.yield(.completed(photo))
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  public func makeStatusRequest(_ change: BearerStatusChange) -> BearerStatusRequest {
    BearerStatusRequest(change: change, idempotencyKey: uuid().uuidString.lowercased(), clientAt: date.now)
  }

  public func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus {
    try await repository.sendStatus(flagID: flagID, request: request)
  }

  public func enqueueStatus(flagID: String, ownerUserID: String, request: BearerStatusRequest) async {
    await outbox.enqueue(flagID: flagID, ownerUserID: ownerUserID, request: request)
  }

  public func pendingStatus(flagID: String) async -> [BearerStatusRequest] {
    await outbox.pending(flagID: flagID)
  }

  public func statusEvents(flagID: String) async -> AsyncStream<BearerOutboxEvent> {
    await outbox.events(flagID: flagID)
  }

  public func retryPendingStatus() async {
    await outbox.resume()
  }

  public func inviteCoBearer(flagID: String) async throws -> BearerInvite {
    try await repository.inviteCoBearer(flagID: flagID)
  }

  public func removeCoBearer(flagID: String, userID: String) async throws {
    try await repository.removeCoBearer(flagID: flagID, userID: userID)
  }
}
