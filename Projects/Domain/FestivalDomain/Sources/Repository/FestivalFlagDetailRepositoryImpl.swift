//
//  FestivalFlagDetailRepositoryImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/7/26.
//

import APIEndpoint
import Dependencies
import FestiCoreNetworkInterface
import FestivalDomainInterface
import Foundation

/// 공용 네트워크 클라이언트로 깃발 상세를 받고 신고·대표 깃발 지정을 보낸다. 사진 경로는 앱의 이미지 주소 해석기를 쓴다.
public struct FestivalFlagDetailRepositoryImpl: FestivalFlagDetailRepositoryInterface {
  @Dependency(\.networkClient) private var client
  @Dependency(\.festivalCatalogService) private var catalogService

  public init() {}

  public func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail {
    // 경로 한 칸에 들어가는 서버 ID 형식만 보낸다.
    guard Self.isValidID(flagID) else { throw .notFound }
    let response: FestivalFlagDetailResponseDTO
    do {
      response = try await client.send(
        PublicFlagRequest.detail(flagID: flagID),
        as: FestivalFlagDetailResponseDTO.self
      )
    } catch {
      throw Self.map(error)
    }
    guard response.code == "SUCCESS", response.data.id == flagID else { throw .invalidResponse }
    return try response.data.toDomain(imageURL: catalogService.imageURL(for:))
  }

  // MARK: - 신고

  public func report(
    flagID: String,
    reason: FestivalFlagReportReason
  ) async throws(FestivalFlagReportError) {
    guard Self.isValidID(flagID) else { throw .invalidRequest }
    let response: FestivalFlagReportResponseDTO
    do {
      response = try await client.send(
        FlagUserRequest.report(
          flagID: flagID,
          body: FestivalFlagActionBodyMapper.reportBody(reason)
        ),
        as: FestivalFlagReportResponseDTO.self
      )
    } catch {
      throw Self.mapReport(error)
    }
    guard response.code == "SUCCESS", !response.data.reportId.isEmpty else { throw .invalidResponse }
  }

  // MARK: - 잠금화면 대표 깃발

  public func setPinnedFlag(_ flagID: String?) async throws(FestivalFlagPinError) -> String? {
    if let flagID, !Self.isValidID(flagID) { throw .invalidRequest }
    let response: FestivalPinnedFlagResponseDTO
    do {
      response = try await client.send(
        FlagUserRequest.pinnedFlag(body: FestivalFlagActionBodyMapper.pinnedFlagBody(flagID)),
        as: FestivalPinnedFlagResponseDTO.self
      )
    } catch {
      throw Self.mapPin(error)
    }
    // 지정을 요청했는데 다른 깃발이 돌아오면 서버 계약과 다르다.
    guard response.code == "SUCCESS", response.data.pinnedFlagId == flagID else { throw .invalidResponse }
    return response.data.pinnedFlagId
  }
}

private extension FestivalFlagDetailRepositoryImpl {
  static func isValidID(_ id: String) -> Bool {
    return !id.isEmpty && id.utf8.allSatisfy { byte in
      return (48 ... 57).contains(byte) || (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
        || byte == 45 || byte == 95
    }
  }

  static func map(_ error: FestiCoreNetworkError) -> FestivalFlagDetailError {
    switch error {
    case let .response(response):
      return response.httpStatus == 404 ? .notFound : .unavailable
    case .decoding:
      return .invalidResponse
    case .request, .transport:
      return .unavailable
    }
  }

  static func mapReport(_ error: FestiCoreNetworkError) -> FestivalFlagReportError {
    switch error {
    case let .response(response):
      if response.isUnauthorized { return .loginRequired }
      switch response.httpStatus {
      case 403 where response.code == "TERMS_REQUIRED": return .termsRequired
      case 404: return .notFound
      case 409 where response.code == "ALREADY_REPORTED": return .alreadyReported
      default: return .unavailable
      }
    case .decoding:
      return .invalidResponse
    case .request:
      return .invalidRequest
    case .transport:
      return .unavailable
    }
  }

  static func mapPin(_ error: FestiCoreNetworkError) -> FestivalFlagPinError {
    switch error {
    case let .response(response):
      if response.isUnauthorized { return .loginRequired }
      switch response.httpStatus {
      case 403 where response.code == "TERMS_REQUIRED": return .termsRequired
      case 409 where response.code == "PIN_NOT_FOLLOWING": return .notFollowing
      default: return .unavailable
      }
    case .decoding:
      return .invalidResponse
    case .request:
      return .invalidRequest
    case .transport:
      return .unavailable
    }
  }
}
