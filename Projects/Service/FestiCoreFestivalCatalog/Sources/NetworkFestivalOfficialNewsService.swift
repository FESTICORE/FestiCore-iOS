//
//  NetworkFestivalOfficialNewsService.swift
//  FestiCoreFestivalCatalog
//
//  Created by FestiCore on 11/20/26.
//

import FestivalDomain
import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation

/// 축제 공식 인스타그램 최근 게시물을 받는다. Meta는 서버만 부르고 앱은 저장된 게시물만 읽는다.
public struct NetworkFestivalOfficialNewsService: FestivalOfficialNewsService {
  private let client: any FestiCoreRequestClient

  public init(client: any FestiCoreRequestClient) {
    self.client = client
  }

  public func officialNews(for festivalID: String) async throws -> FestivalOfficialNews {
    guard !festivalID.isEmpty,
          festivalID.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
            || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 }) else {
      throw FestivalLiveBoardError.invalidFestivalID
    }
    let response: FestivalOfficialNewsResponseDTO
    do {
      response = try await client.send(FestivalOfficialNewsRequest(festivalID: festivalID))
    } catch FestiCoreNetworkError.decoding {
      throw FestivalLiveBoardError.invalidResponse
    }
    guard response.code == "SUCCESS", response.data.festivalId == festivalID else {
      throw FestivalLiveBoardError.invalidResponse
    }
    return response.data.toDomain()
  }
}
