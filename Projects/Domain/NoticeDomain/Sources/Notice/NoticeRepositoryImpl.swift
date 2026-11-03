//
//  NoticeRepositoryImpl.swift
//  NoticeDomain
//

import APIEndpoint
import Dependencies
import FestiCoreNetworkInterface
import NoticeDomainInterface

public struct NoticeRepositoryImpl: NoticeRepositoryInterface {
  @Dependency(\.networkClient) private var client

  public init() {}

  public func notices() async throws -> [NoticeSummary] {
    let response = try await client.send(NoticeRequest.list, as: NoticeListResponseDTO.self)
    guard response.code == "SUCCESS" else { throw NoticeError.invalidResponse }
    return response.data.items.map { $0.toDomain() }
  }

  public func notice(id: String) async throws -> NoticeDetail {
    let response = try await client.send(NoticeRequest.detail(id: id), as: NoticeDetailResponseDTO.self)
    guard response.code == "SUCCESS" else { throw NoticeError.invalidResponse }
    return response.data.toDomain()
  }
}
