//
//  FestivalBearerUseCaseStub.swift
//  FestivalTests
//
//  Created by FestiCore on 11/26/26.
//

import BearerDomainInterface
import Foundation

/// 깃발 상세가 '원래 기수·공동 기수 없음'을 확인할 때 쓰는 기수 UseCase 대역. 나머지는 미등록 대역으로 넘긴다.
struct FestivalBearerUseCaseStub: BearerUseCaseInterface {
  var flags: @Sendable (String?) async throws -> [BearerOwnedFlag] = { _ in return [] }
  var board: @Sendable (String) async throws -> BearerBoard = { try await MockBearerUseCase().fetchBoard(flagID: $0) }
  let unregistered = MockBearerUseCase()

  func fetchBearerFlags(festivalID: String?) async throws -> [BearerOwnedFlag] {
    return try await flags(festivalID)
  }
  func fetchBoard(flagID: String) async throws -> BearerBoard { return try await board(flagID) }

  func makeRegisterRequest(
    festivalID: String,
    change: BearerProfileChange
  ) -> BearerRegisterRequest {
    return unregistered.makeRegisterRequest(
      festivalID: festivalID,
      change: change
    )
  }
  func register(_ request: BearerRegisterRequest) async throws -> BearerClaim { return try await unregistered.register(request) }
  func fetchPinnedFlag() async throws -> BearerPinnedFlag? { return try await unregistered.fetchPinnedFlag() }
  func fetchFollowedFlags(festivalID: String?) async throws -> [BearerFollowedFlag] { return try await unregistered.fetchFollowedFlags(festivalID: festivalID) }
  func claim(
    festivalID: String,
    code: String
  ) async throws -> BearerClaim {
    return try await unregistered.claim(
      festivalID: festivalID,
      code: code
    )
  }
  func fetchFestival(festivalID: String) async throws -> BearerFestival {
    return try await unregistered.fetchFestival(festivalID: festivalID)
  }
  func makeFestivalTransferRequest(
    flagID: String,
    fromFestivalID: String,
    toFestivalID: String
  ) -> BearerFestivalTransferRequest {
    return unregistered.makeFestivalTransferRequest(
      flagID: flagID,
      fromFestivalID: fromFestivalID,
      toFestivalID: toFestivalID
    )
  }
  func transferFestival(_ request: BearerFestivalTransferRequest) async throws -> BearerFestivalTransfer { return try await unregistered.transferFestival(request) }
  func updateProfile(
    flagID: String,
    change: BearerProfileChange
  ) async throws -> BearerFlagProfile {
    return try await unregistered.updateProfile(
      flagID: flagID,
      change: change
    )
  }
  func uploadPhoto(
    flagID: String,
    imageData: Data
  ) -> AsyncThrowingStream<BearerPhotoUploadEvent, Error> {
    return unregistered.uploadPhoto(
      flagID: flagID,
      imageData: imageData
    )
  }
  func makeStatusRequest(_ change: BearerStatusChange) -> BearerStatusRequest { return unregistered.makeStatusRequest(change) }
  func sendStatus(
    flagID: String,
    request: BearerStatusRequest
  ) async throws -> BearerFlagStatus {
    return try await unregistered.sendStatus(
      flagID: flagID,
      request: request
    )
  }
  func enqueueStatus(
    flagID: String,
    ownerUserID: String,
    request: BearerStatusRequest
  ) async {
    await unregistered.enqueueStatus(
      flagID: flagID,
      ownerUserID: ownerUserID,
      request: request
    )
  }
  func pendingStatus(flagID: String) async -> [BearerStatusRequest] { return await unregistered.pendingStatus(flagID: flagID) }
  func statusEvents(flagID: String) async -> AsyncStream<BearerOutboxEvent> { return await unregistered.statusEvents(flagID: flagID) }
  func retryPendingStatus() async { await unregistered.retryPendingStatus() }
  func inviteCoBearer(flagID: String) async throws -> BearerInvite { return try await unregistered.inviteCoBearer(flagID: flagID) }
  func removeCoBearer(
    flagID: String,
    userID: String
  ) async throws {
    try await unregistered.removeCoBearer(
      flagID: flagID,
      userID: userID
    )
  }
}
