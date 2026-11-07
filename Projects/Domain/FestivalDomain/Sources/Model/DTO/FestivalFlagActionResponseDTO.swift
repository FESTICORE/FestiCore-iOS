//
//  FestivalFlagActionResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreNetworkInterface
import Foundation

typealias FestivalFlagReportResponseDTO = BaseResponseDTO<FestivalFlagReportDataDTO>

/// `POST flags/:flagId/report` 응답 data
struct FestivalFlagReportDataDTO: Decodable, Sendable {
  let reportId: String
}

typealias FestivalPinnedFlagResponseDTO = BaseResponseDTO<FestivalPinnedFlagDataDTO>

/// `PUT me/pinned-flag` 응답 data. 해제했으면 pinnedFlagId가 null이다.
struct FestivalPinnedFlagDataDTO: Decodable, Sendable {
  let pinnedFlagId: String?

  private enum CodingKeys: String, CodingKey {
    case pinnedFlagId
  }

  /// 키가 빠진 응답은 해제와 구분할 수 없어 형식 오류로 막는다.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    guard container.contains(.pinnedFlagId) else {
      throw DecodingError.keyNotFound(
        CodingKeys.pinnedFlagId,
        .init(
          codingPath: container.codingPath,
          debugDescription: "pinnedFlagId가 없습니다."
        )
      )
    }
    pinnedFlagId = try container.decodeIfPresent(
      String.self,
      forKey: .pinnedFlagId
    )
  }
}
