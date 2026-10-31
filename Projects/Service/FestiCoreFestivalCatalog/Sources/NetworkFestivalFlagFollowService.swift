//
//  NetworkFestivalFlagFollowService.swift
//  FestiCoreFestivalCatalog
//
//  Created by FestiCore on 10/31/26.
//

import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation

public struct NetworkFestivalFlagFollowService: FestivalFlagFollowService {
  private let client: any FestiCoreRequestClient
  private let auth: any AuthService
  private let makeKey: @Sendable () -> String

  public init(
    client: any FestiCoreRequestClient,
    auth: any AuthService,
    makeKey: @escaping @Sendable () -> String = { UUID().uuidString }
  ) {
    self.client = client
    self.auth = auth
    self.makeKey = makeKey
  }

  public func setFollowing(
    _ following: Bool,
    flagID: String
  ) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult {
    guard !flagID.isEmpty,
          flagID.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
            || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 })
    else {
      throw .invalidResponse
    }
    // 연결이 끊긴 로그아웃 상태에서도 로그인 안내가 뜨도록 요청 전에 확인한다.
    guard await auth.isLoggedIn else { throw .loginRequired }
    let request = FestivalFlagFollowRequest(
      flagID: flagID,
      following: following,
      idempotencyKey: makeKey()
    )
    let response: FestivalFlagFollowResponseDTO
    do {
      response = try await client.send(request)
    } catch {
      throw Self.map(error)
    }
    guard response.code == "SUCCESS", response.data.flagId == flagID else {
      throw .invalidResponse
    }
    return response.data.toDomain()
  }
}

private extension NetworkFestivalFlagFollowService {
  static func map(_ error: FestiCoreNetworkError) -> FestivalFlagFollowError {
    switch error {
    case let .response(responseError):
      if responseError.isUnauthorized { return .loginRequired }
      switch (responseError.httpStatus, responseError.code) {
      case (404, _): return .notFound
      case (403, "TERMS_REQUIRED"): return .termsRequired
      // 409는 멱등 키 충돌(IDEMPOTENCY_CONFLICT)도 있으므로 한도 초과 코드만 구분한다.
      case (409, "FOLLOW_LIMIT"): return .limitReached
      default: return .unavailable
      }
    case .decoding:
      return .invalidResponse
    case .request:
      return .invalidResponse
    case .transport:
      return .unavailable
    }
  }
}
