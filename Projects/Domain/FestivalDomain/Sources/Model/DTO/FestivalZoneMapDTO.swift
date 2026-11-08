//
//  FestivalZoneMapDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/8/26.
//

import Foundation

/// 받아 둔 팩 문서에서 존 지도가 쓰는 값만 읽는다. 형식이 틀린 항목은 건너뛴다.
struct FestivalZoneMapPackDTO: Decodable, Sendable {
  let mapImageUrl: String?
  let mapAspect: Double?
  let mapVersion: String?
  let flagsEnabled: Bool?
  let zones: [ZoneDTO]
  let mapStages: [StageHeaderDTO]
  let stages: [StageDTO]
  let sets: [SetDTO]

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mapImageUrl = try? container.decodeIfPresent(
      String.self,
      forKey: .mapImageUrl
    )
    mapAspect = try? container.decodeIfPresent(
      Double.self,
      forKey: .mapAspect
    )
    mapVersion = try? container.decodeIfPresent(
      String.self,
      forKey: .mapVersion
    )
    flagsEnabled = try? container.decodeIfPresent(
      Bool.self,
      forKey: .flagsEnabled
    )
    zones = Self.lossy(
      container,
      .zones
    )
    mapStages = Self.lossy(
      container,
      .mapStages
    )
    stages = Self.lossy(
      container,
      .stages
    )
    sets = Self.lossy(
      container,
      .sets
    )
  }

  private enum CodingKeys: String, CodingKey {
    case mapImageUrl, mapAspect, mapVersion, flagsEnabled, zones, mapStages, stages, sets
  }

  private static func lossy<Item: Decodable>(
    _ container: KeyedDecodingContainer<CodingKeys>,
    _ key: CodingKeys
  ) -> [Item] {
    let items = (try? container.decodeIfPresent(
      [Lossy<Item>].self,
      forKey: key
    )) ?? []
    return items.compactMap(\.value)
  }
}

extension FestivalZoneMapPackDTO {
  struct ZoneDTO: Decodable, Sendable {
    let id: String
    let name: String
    let kind: String?
    let order: Int?
    let area: AreaDTO?
    let landmark: String?
  }

  struct AreaDTO: Decodable, Sendable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
  }

  struct StageHeaderDTO: Decodable, Sendable {
    let stageId: String
    let x: Double
    let y: Double
    let w: Double
  }

  struct StageDTO: Decodable, Sendable {
    let id: String
    let name: String
  }

  struct SetDTO: Decodable, Sendable {
    let stageId: String?
    let artist: String?
    let startsAt: String?
    let endsAt: String?
  }

  /// 항목 하나의 형식 오류가 배열 전체를 버리지 않게 한다.
  struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
      value = try? Value(from: decoder)
    }
  }
}

/// `GET festivals/:id/pack/version` 응답
struct FestivalPackVersionResponseDTO: Decodable, Sendable {
  let code: String
  let data: FestivalPackVersionDataDTO
}

struct FestivalPackVersionDataDTO: Decodable, Sendable {
  let packVersion: Int
  let mapVersion: String?
}
