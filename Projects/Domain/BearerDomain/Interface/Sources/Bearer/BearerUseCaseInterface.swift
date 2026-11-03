//
//  BearerUseCaseInterface.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import Foundation

/// 기수 화면(코드 등록·깃발 프로필·기수 보드)이 하는 일
public protocol BearerUseCaseInterface: Sendable {
  func claim(festivalID: String, code: String) async throws -> BearerClaim
  /// 기기에 받아 둔 팩에서 축제 이름과 존을 읽는다. 팩이 없으면 빈 존 목록이다.
  func fetchFestival(festivalID: String) async throws -> BearerFestival
  func fetchBoard(flagID: String) async throws -> BearerBoard
  func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile
  /// 고른 사진을 JPEG 5MB 이하로 맞춘 뒤 올린다. 256×256보다 작으면 올리지 않는다.
  /// 스트림을 끝까지 읽지 않고 취소하면 전송도 취소한다.
  func uploadPhoto(flagID: String, imageData: Data) -> AsyncThrowingStream<BearerPhotoUploadEvent, Error>
  /// 누른 시각과 새 멱등키로 전송 한 건을 만든다.
  func makeStatusRequest(_ change: BearerStatusChange) -> BearerStatusRequest
  func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus
  /// 대기열에 넣는다. 보드를 닫아도 이어서 보낸다.
  func enqueueStatus(flagID: String, request: BearerStatusRequest) async
  func pendingStatus(flagID: String) async -> [BearerStatusRequest]
  func statusEvents(flagID: String) async -> AsyncStream<BearerOutboxEvent>
  /// 멈춘 전송을 다시 시작한다.
  func retryPendingStatus() async
  func inviteCoBearer(flagID: String) async throws -> BearerInvite
  func removeCoBearer(flagID: String, userID: String) async throws
}

public enum BearerUseCaseDependency: TestDependencyKey {
  public static var testValue: any BearerUseCaseInterface { MockBearerUseCase() }
  public static var previewValue: any BearerUseCaseInterface { testValue }
}

public extension DependencyValues {
  var bearerUseCase: any BearerUseCaseInterface {
    get { self[BearerUseCaseDependency.self] }
    set { self[BearerUseCaseDependency.self] = newValue }
  }
}
