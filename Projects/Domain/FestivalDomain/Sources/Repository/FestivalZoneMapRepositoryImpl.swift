//
//  FestivalZoneMapRepositoryImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/8/26.
//

import APIEndpoint
import Dependencies
import FestiCoreNetworkInterface
import FestivalDomainInterface

/// 공용 NetworkClient로 현재 발행 팩의 지도 버전을 조회하는 Repository
public struct FestivalZoneMapRepositoryImpl: FestivalZoneMapRepositoryInterface {
  @Dependency(\.networkClient) private var client

  public init() {}

  public func latestMapVersion(festivalID: String) async throws -> String? {
    let response = try await client.send(
      FestivalPackRequest.version(festivalID: festivalID),
      as: FestivalPackVersionResponseDTO.self
    )
    guard response.code == "SUCCESS" else { throw FestivalPackError.invalidResponse }
    return response.data.mapVersion
  }
}
