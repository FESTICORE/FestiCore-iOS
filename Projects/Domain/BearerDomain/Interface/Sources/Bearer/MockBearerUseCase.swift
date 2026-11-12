//
//  MockBearerUseCase.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation
import IssueReporting

/// 주입하지 않은 기수 UseCase. 호출하면 테스트 이슈를 남기고 실패한다.
public struct MockBearerUseCase: BearerUseCaseInterface {
  private let repository: MockBearerRepository
  private let dependencyName: String

  public init(dependencyName: String = "bearerUseCase") {
    self.dependencyName = dependencyName
    repository = MockBearerRepository(dependencyName: dependencyName)
  }

  public func claim(festivalID: String, code: String) async throws -> BearerClaim {
    try await repository.claim(festivalID: festivalID, code: code)
  }

  public func makeRegisterRequest(
    festivalID: String,
    change: BearerProfileChange
  ) -> BearerRegisterRequest {
    reportIssue("\(dependencyName) 미등록")
    return BearerRegisterRequest(
      festivalID: festivalID,
      change: change,
      idempotencyKey: ""
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

  public func fetchFestival(festivalID: String) async throws -> BearerFestival {
    reportIssue("\(dependencyName) 미등록")
    throw BearerError.unavailable
  }

  public func fetchBoard(flagID: String) async throws -> BearerBoard {
    try await repository.fetchBoard(flagID: flagID)
  }

  public func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile {
    try await repository.updateProfile(flagID: flagID, change: change)
  }

  public func uploadPhoto(flagID: String, imageData: Data) -> AsyncThrowingStream<BearerPhotoUploadEvent, Error> {
    reportIssue("\(dependencyName) 미등록")
    return AsyncThrowingStream { $0.finish(throwing: BearerError.unavailable) }
  }

  public func makeStatusRequest(_ change: BearerStatusChange) -> BearerStatusRequest {
    reportIssue("\(dependencyName) 미등록")
    return BearerStatusRequest(change: change, idempotencyKey: "", clientAt: Date(timeIntervalSince1970: 0))
  }

  public func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus {
    try await repository.sendStatus(flagID: flagID, request: request)
  }

  public func enqueueStatus(flagID: String, ownerUserID: String, request: BearerStatusRequest) async {
    reportIssue("\(dependencyName) 미등록")
  }

  public func pendingStatus(flagID: String) async -> [BearerStatusRequest] {
    reportIssue("\(dependencyName) 미등록")
    return []
  }

  public func statusEvents(flagID: String) async -> AsyncStream<BearerOutboxEvent> {
    reportIssue("\(dependencyName) 미등록")
    return AsyncStream { $0.finish() }
  }

  public func retryPendingStatus() async {
    reportIssue("\(dependencyName) 미등록")
  }

  public func inviteCoBearer(flagID: String) async throws -> BearerInvite {
    try await repository.inviteCoBearer(flagID: flagID)
  }

  public func removeCoBearer(flagID: String, userID: String) async throws {
    try await repository.removeCoBearer(flagID: flagID, userID: userID)
  }
}
