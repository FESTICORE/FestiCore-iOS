//
//  FestivalFlagDetailResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/7/26.
//

import FestiCoreNetworkInterface
import Foundation

typealias FestivalFlagDetailResponseDTO = BaseResponseDTO<FestivalFlagDetailDataDTO>

/// `GET flags/:flagId` 응답 data. 익명 조회면 isFollowing·isBearer·isPinned가 null이다.
struct FestivalFlagDetailDataDTO: Decodable, Sendable {
  struct StatusDTO: Decodable, Sendable {
    let flagId: String
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
  /// 대표 깃발 여부. 이 필드를 내려 주기 전 서버면 없다.
  let isPinned: Bool?
  let hidden: Bool

  fileprivate enum CodingKeys: String, CodingKey {
    case id, name, thumbUrl, photoUrl, tags, bio, followerCount, planVisible, plan, homeZoneId, status
    case isFollowing, isBearer, isPinned, hidden
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
    tags = try Self.strings(
      in: container,
      forKey: .tags
    )
    bio = try container.decodeIfPresent(
      String.self,
      forKey: .bio
    )
    followerCount = try container.decode(
      Int.self,
      forKey: .followerCount
    )
    planVisible = try container.decode(
      Bool.self,
      forKey: .planVisible
    )
    plan = try Self.strings(
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
    isPinned = try container.decodeIfPresent(
      Bool.self,
      forKey: .isPinned
    )
    hidden = try container.decode(
      Bool.self,
      forKey: .hidden
    )
  }
}

private extension FestivalFlagDetailDataDTO {
  /// 배열은 필수다. 배열 안에서 문자열이 아닌 원소만 버린다.
  static func strings(
    in container: KeyedDecodingContainer<CodingKeys>,
    forKey key: CodingKeys
  ) throws -> [String] {
    let values = try container.decode(
      [StringValue].self,
      forKey: key
    )
    return values.compactMap(\.value)
  }

  struct StringValue: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
      value = try? decoder.singleValueContainer().decode(String.self)
    }
  }
}
