//
//  FestivalFlagDetailResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/7/26.
//

import FestiCoreNetworkInterface
import Foundation

typealias FestivalFlagDetailResponseDTO = BaseResponseDTO<FestivalFlagDetailDataDTO>

/// `GET flags/:flagId` 응답 data. 익명 조회면 isFollowing·isBearer가 null이다.
struct FestivalFlagDetailDataDTO: Decodable, Sendable {
  struct StatusDTO: Decodable, Sendable {
    let status: String
    let zoneId: String?
    let activity: String?
    let updatedAt: String
  }

  let id: String
  let name: String
  let thumbUrl: String?
  let photoUrl: String?
  let tags: [String]
  let bio: String?
  let followerCount: Int
  let planVisible: Bool
  let plan: [String]
  let homeZoneId: String?
  let status: StatusDTO
  let isFollowing: Bool?
  let isBearer: Bool?
  let hidden: Bool

  fileprivate enum CodingKeys: String, CodingKey {
    case id, name, thumbUrl, photoUrl, tags, bio, followerCount, planVisible, plan, homeZoneId, status
    case isFollowing, isBearer, hidden
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(
      String.self,
      forKey: .id
    )
    name = try container.decode(
      String.self,
      forKey: .name
    )
    thumbUrl = try container.decodeIfPresent(
      String.self,
      forKey: .thumbUrl
    )
    photoUrl = try container.decodeIfPresent(
      String.self,
      forKey: .photoUrl
    )
    tags = Self.strings(
      in: container,
      forKey: .tags
    )
    bio = try container.decodeIfPresent(
      String.self,
      forKey: .bio
    )
    followerCount = try container.decodeIfPresent(
      Int.self,
      forKey: .followerCount
    ) ?? 0
    planVisible = try container.decodeIfPresent(
      Bool.self,
      forKey: .planVisible
    ) ?? false
    plan = Self.strings(
      in: container,
      forKey: .plan
    )
    homeZoneId = try container.decodeIfPresent(
      String.self,
      forKey: .homeZoneId
    )
    status = try container.decode(
      StatusDTO.self,
      forKey: .status
    )
    isFollowing = try container.decodeIfPresent(
      Bool.self,
      forKey: .isFollowing
    )
    isBearer = try container.decodeIfPresent(
      Bool.self,
      forKey: .isBearer
    )
    hidden = try container.decodeIfPresent(
      Bool.self,
      forKey: .hidden
    ) ?? false
  }
}

private extension FestivalFlagDetailDataDTO {
  /// 문자열이 아닌 원소는 버린다. 배열이 없거나 형식이 다르면 빈 배열이다.
  static func strings(
    in container: KeyedDecodingContainer<CodingKeys>,
    forKey key: CodingKeys
  ) -> [String] {
    guard let values = try? container.decode(
      [StringValue].self,
      forKey: key
    ) else {
      return []
    }
    return values.compactMap(\.value)
  }

  struct StringValue: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
      value = try? decoder.singleValueContainer().decode(String.self)
    }
  }
}
