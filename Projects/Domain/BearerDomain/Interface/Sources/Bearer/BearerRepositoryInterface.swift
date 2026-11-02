//
//  BearerRepositoryInterface.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import Foundation

/// 기수 API 저장소. 로그인 세션에 묶여 서버와 통신한다.
public protocol BearerRepositoryInterface: Sendable {
  func claim(festivalID: String, code: String) async throws -> BearerClaim
  func fetchBoard(flagID: String) async throws -> BearerBoard
  func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile
  /// 업로드 규격(JPEG·5MB 이하)을 맞춘 데이터를 multipart로 올린다.
  func uploadPhoto(flagID: String, jpegData: Data) async throws -> BearerFlagPhoto
  func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus
  func inviteCoBearer(flagID: String) async throws -> BearerInvite
  func removeCoBearer(flagID: String, userID: String) async throws
}

public enum BearerRepositoryDependency: TestDependencyKey {
  public static var testValue: any BearerRepositoryInterface { MockBearerRepository() }
  public static var previewValue: any BearerRepositoryInterface { testValue }
}

public extension DependencyValues {
  var bearerRepository: any BearerRepositoryInterface {
    get { self[BearerRepositoryDependency.self] }
    set { self[BearerRepositoryDependency.self] = newValue }
  }
}
