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
  /// 코드 없이 깃발을 만들고 원래 기수가 된다. 응답은 코드 등록과 같다.
  func register(_ request: BearerRegisterRequest) async throws -> BearerClaim
  /// 내가 기수인 깃발. `festivalID`를 주면 그 페스티벌 것만 받는다.
  func fetchBearerFlags(festivalID: String?) async throws -> [BearerOwnedFlag]
  /// 내 대표 깃발. 지정하지 않았으면 nil이다.
  func fetchPinnedFlag() async throws -> BearerPinnedFlag?
  /// 내가 팔로우한 깃발(최근 팔로우순)과 이름. 공개 조회할 수 없는 깃발은 뺀다.
  func fetchFollowedFlags(festivalID: String?) async throws -> [BearerFollowedFlag]
  func fetchBoard(flagID: String) async throws -> BearerBoard
  func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile
  /// 업로드 규격(JPEG·5MB 이하)을 맞춘 데이터를 multipart로 올리며 보낸 비율을 알린다.
  func uploadPhoto(
    flagID: String,
    jpegData: Data,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> BearerFlagPhoto
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
