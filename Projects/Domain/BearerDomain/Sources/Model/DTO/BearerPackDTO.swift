//
//  BearerPackDTO.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 받아 둔 팩 문서에서 기수 화면이 쓰는 이름·존·공연만 읽는다. 형식이 틀린 항목은 건너뛴다.
struct BearerPackDTO: Decodable, Sendable {
  struct Zone: Decodable, Sendable {
    let id: String?
    let name: String?

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try? container.decodeIfPresent(String.self, forKey: .id)
      name = try? container.decodeIfPresent(String.self, forKey: .name)
    }

    private enum CodingKeys: String, CodingKey {
      case id, name
    }
  }

  struct Stage: Decodable, Sendable {
    let id: String?
    let name: String?

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try? container.decodeIfPresent(
        String.self,
        forKey: .id
      )
      name = try? container.decodeIfPresent(
        String.self,
        forKey: .name
      )
    }

    private enum CodingKeys: String, CodingKey {
      case id, name
    }
  }

  struct Performance: Decodable, Sendable {
    let id: String?
    let artist: String?
    let stageId: String?
    let stageName: String?
    let startsAt: String?
    let endsAt: String?

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try? container.decodeIfPresent(
        String.self,
        forKey: .id
      )
      artist = try? container.decodeIfPresent(
        String.self,
        forKey: .artist
      )
      stageId = try? container.decodeIfPresent(
        String.self,
        forKey: .stageId
      )
      stageName = try? container.decodeIfPresent(
        String.self,
        forKey: .stageName
      )
      startsAt = try? container.decodeIfPresent(
        String.self,
        forKey: .startsAt
      )
      endsAt = try? container.decodeIfPresent(
        String.self,
        forKey: .endsAt
      )
    }

    private enum CodingKeys: String, CodingKey {
      case id, artist, stageId, stageName, startsAt, endsAt
    }
  }

  let name: String?
  let zones: [Zone]?
  let stages: [Stage]?
  let performances: [Performance]?

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try? container.decodeIfPresent(String.self, forKey: .name)
    zones = try? container.decodeIfPresent([Zone].self, forKey: .zones)
    stages = try? container.decodeIfPresent(
      [Stage].self,
      forKey: .stages
    )
    performances = try? container.decodeIfPresent(
      [Performance].self,
      forKey: .performances
    )
  }

  private enum CodingKeys: String, CodingKey {
    case name, zones, stages, performances
  }
}
