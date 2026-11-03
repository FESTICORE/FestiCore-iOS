//
//  FestivalPackRepositoryImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import APIEndpoint
import Dependencies
import FestiCoreNetworkInterface
import FestivalDomainInterface

public struct FestivalPackRepositoryImpl: FestivalPackRepositoryInterface {
  @Dependency(\.networkClient) private var client

  public init() {}

  public func packChanges(festivalID: String, fromVersion: Int) async throws -> FestivalPackChanges {
    let response = try await client.send(
      FestivalPackRequest.changes(festivalID: festivalID, fromVersion: fromVersion),
      as: FestivalPackChangesResponseDTO.self
    )
    guard response.code == "SUCCESS" else { throw FestivalPackError.invalidResponse }
    return response.data.toDomain()
  }
}
