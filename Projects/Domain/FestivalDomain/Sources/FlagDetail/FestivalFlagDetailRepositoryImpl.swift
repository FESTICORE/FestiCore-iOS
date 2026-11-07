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

/// 공용 네트워크 클라이언트로 공개 깃발 상세를 받아 도메인 값으로 바꾼다. 사진 경로는 앱의 이미지 주소 해석기를 쓴다.
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
}
