//
//  NetworkFestivalScheduleService.swift
//  FestiCoreFestivalCatalog
//
//  Created by FestiCore on 10/30/26.
//

import Alamofire
import FestiCoreNetworkInterface
import FestiCoreUtility
import FestivalDomain
import FestivalDomainInterface
import Foundation

public struct NetworkFestivalScheduleService: FestivalScheduleService {
  private let client: any FestiCoreRequestClient

  public init(client: any FestiCoreRequestClient) {
    self.client = client
  }

  public func fetch(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    try Self.validate(festivalID)
    let response: FestivalScheduleResponseDTO
    do {
      response = try await client.send(ScheduleGetRequest(festivalID: festivalID))
    } catch {
      throw Self.map(error)
    }
    return try Self.schedule(from: response)
  }

  public func replace(
    festivalID: String,
    setIDs: [String],
    clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    try Self.validate(festivalID)
    let request = SchedulePutRequest(
      festivalID: festivalID,
      body: .init(setIds: setIDs, clientAt: Self.clientAtString(clientAt))
    )
    let response: FestivalScheduleResponseDTO
    do {
      response = try await client.send(request)
    } catch {
      // 409 본문은 send 경로에서 남지 않으므로 서버 값을 다시 읽어 돌려준다.
      if case let .response(responseError) = error,
         responseError.httpStatus == 409,
         responseError.code == "STATUS_STALE"
      {
        throw try .stale(await fetch(festivalID: festivalID))
      }
      throw Self.map(error)
    }
    return try Self.schedule(from: response)
  }
}

extension NetworkFestivalScheduleService {
  /// 서버는 ms 단위로 비교하므로 소수점 3자리까지 보낸다.
  static func clientAtString(_ date: Date) -> String {
    date.isoString
  }
}

private extension NetworkFestivalScheduleService {
  static func validate(_ festivalID: String) throws(FestivalScheduleError) {
    guard !festivalID.isEmpty,
          festivalID.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
              || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 })
    else {
      throw .rejected
    }
  }

  static func schedule(from response: FestivalScheduleResponseDTO) throws(FestivalScheduleError) -> FestivalSchedule {
    guard response.code == "SUCCESS" else { throw .unavailable }
    return response.data.toDomain()
  }

  static func map(_ error: FestiCoreNetworkError) -> FestivalScheduleError {
    guard case let .response(responseError) = error else { return .unavailable }
    if responseError.isUnauthorized {
      return .unauthorized
    }
    // 검증 실패만 거부로 본다. 429 등은 저장 여부를 알 수 없는 실패로 둔다.
    if responseError.httpStatus == 400 {
      return .rejected
    }
    return .unavailable
  }
}

private struct ScheduleGetRequest: FestiCoreDataRequest {
  typealias Response = FestivalScheduleResponseDTO
  let festivalID: String
  var path: String {
    "api/v1/me/schedule/\(festivalID)"
  }

  var method: HTTPMethod {
    .get
  }
}

struct SchedulePutRequest: FestiCoreDataRequest {
  typealias Response = FestivalScheduleResponseDTO

  struct Body: Encodable, Equatable, Sendable {
    let setIds: [String]
    let clientAt: String
  }

  let festivalID: String
  let body: Body
  var path: String {
    "api/v1/me/schedule/\(festivalID)"
  }

  var method: HTTPMethod {
    .put
  }

  var parameters: (any Encodable & Sendable)? {
    body
  }
}
