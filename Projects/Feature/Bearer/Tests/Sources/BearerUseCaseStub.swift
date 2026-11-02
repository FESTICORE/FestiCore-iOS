//
//  BearerUseCaseStub.swift
//  BearerTests
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Foundation
import Testing

/// 테스트마다 필요한 동작만 채우는 기수 UseCase 대역. 채우지 않은 호출은 테스트 이슈다.
struct BearerUseCaseStub: BearerUseCaseInterface {
  var claim: @Sendable (String, String) async throws -> BearerClaim = { _, _ in try unexpected() }
  var fetchFestival: @Sendable (String) async throws -> BearerFestival = { _ in try unexpected() }
  var fetchBoard: @Sendable (String) async throws -> BearerBoard = { _ in try unexpected() }
  var updateProfile: @Sendable (String, BearerProfileChange) async throws -> BearerFlagProfile = { _, _ in try unexpected() }
  var uploadPhoto: @Sendable (String, Data) -> AsyncThrowingStream<BearerPhotoUploadEvent, Error> = { _, _ in
    Issue.record("uploadPhoto 미주입")
    return AsyncThrowingStream { $0.finish(throwing: BearerError.unavailable) }
  }
  var makeStatusRequest: @Sendable (BearerStatusChange) -> BearerStatusRequest = { change in
    Issue.record("makeStatusRequest 미주입")
    return BearerStatusRequest(change: change, idempotencyKey: "", clientAt: Date(timeIntervalSince1970: 0))
  }
  var sendStatus: @Sendable (String, BearerStatusRequest) async throws -> BearerFlagStatus = { _, _ in try unexpected() }
  var inviteCoBearer: @Sendable (String) async throws -> BearerInvite = { _ in try unexpected() }
  var removeCoBearer: @Sendable (String, String) async throws -> Void = { _, _ in try unexpected() }

  func claim(festivalID: String, code: String) async throws -> BearerClaim { try await claim(festivalID, code) }
  func fetchFestival(festivalID: String) async throws -> BearerFestival { try await fetchFestival(festivalID) }
  func fetchBoard(flagID: String) async throws -> BearerBoard { try await fetchBoard(flagID) }
  func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile {
    try await updateProfile(flagID, change)
  }
  func uploadPhoto(flagID: String, imageData: Data) -> AsyncThrowingStream<BearerPhotoUploadEvent, Error> {
    uploadPhoto(flagID, imageData)
  }
  func makeStatusRequest(_ change: BearerStatusChange) -> BearerStatusRequest { makeStatusRequest(change) }
  func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus {
    try await sendStatus(flagID, request)
  }
  func inviteCoBearer(flagID: String) async throws -> BearerInvite { try await inviteCoBearer(flagID) }
  func removeCoBearer(flagID: String, userID: String) async throws { try await removeCoBearer(flagID, userID) }
}

private func unexpected<T>() throws -> T {
  Issue.record("미주입 기수 UseCase 호출")
  throw BearerError.unavailable
}

/// 테스트·미리보기용 샘플 값
enum BearerSample {
  static let profile = BearerFlagProfile(id: "flg_1", name: "새 깃발 a1b2c3", tags: [.newbie])
  static let claim = BearerClaim(flagID: "flg_1", profile: profile, isNew: true, coBearerIDs: ["usr_1"])
}
