//
//  BearerPackDTO.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 받아 둔 팩 문서에서 기수 화면이 쓰는 이름과 존만 읽는다. 형식이 틀린 존은 건너뛴다.
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

  let name: String?
  let zones: [Zone]?

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try? container.decodeIfPresent(String.self, forKey: .name)
    zones = try? container.decodeIfPresent([Zone].self, forKey: .zones)
  }

  private enum CodingKeys: String, CodingKey {
    case name, zones
  }
}
