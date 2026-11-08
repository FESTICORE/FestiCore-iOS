//
//  FestivalZoneMap.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/8/26.
//

import Foundation

/// Figma S06 존 지도. 받아 둔 팩의 존 영역·무대 머리글과 지도 버전이다.
public struct FestivalZoneMap: Equatable, Sendable {
  public let festivalID: String
  /// 지도 데이터가 바뀔 때만 바뀌는 버전(`mapVersion`). 존이 없으면 nil이다.
  public let version: String?
  public let imageURL: URL?
  /// 지도 너비/높이. 존 영역을 화면 좌표로 바꿀 때 쓴다.
  public let aspect: Double?
  /// 팩의 깃발 기능 사용 여부. 꺼져 있으면 크루만 보여 준다(Figma S06 H).
  public let flagsEnabled: Bool
  public let zones: [Zone]
  public let stageHeaders: [StageHeader]

  public init(
    festivalID: String,
    version: String?,
    imageURL: URL?,
    aspect: Double?,
    flagsEnabled: Bool,
    zones: [Zone],
    stageHeaders: [StageHeader]
  ) {
    self.festivalID = festivalID
    self.version = version
    self.imageURL = imageURL
    self.aspect = aspect
    self.flagsEnabled = flagsEnabled
    self.zones = zones
    self.stageHeaders = stageHeaders
  }

  /// 영역이 있는 존이 하나라도 있으면 지도를 그린다. 없으면 존 목록(Figma S06 I)이다.
  public var hasLayout: Bool {
    return aspect != nil && zones.contains { $0.area != nil }
  }

  public func zone(id: String?) -> Zone? {
    return zones.first { $0.id == id }
  }
}

public extension FestivalZoneMap {
  /// 존 하나. 영역은 지도 왼쪽 위 기준 0~1 비율이다.
  struct Zone: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// 존 카드 보조 문구(예: 무대 앞)
    public let kind: String?
    public let area: Area?
    /// 영역 오른쪽 위 표지(예: TENT 무대)
    public let landmark: String?

    public init(
      id: String,
      name: String,
      kind: String?,
      area: Area?,
      landmark: String?
    ) {
      self.id = id
      self.name = name
      self.kind = kind
      self.area = area
      self.landmark = landmark
    }
  }

  /// 0~1 비율 사각형
  struct Area: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(
      x: Double,
      y: Double,
      width: Double,
      height: Double
    ) {
      self.x = x
      self.y = y
      self.width = width
      self.height = height
    }
  }

  /// 무대 이름과 지금 공연 중인 아티스트를 보여 주는 머리글 줄
  struct StageHeader: Equatable, Sendable, Identifiable {
    public let stageID: String
    public let name: String
    public let x: Double
    public let y: Double
    public let width: Double
    /// 기준 시각에 이 무대에서 공연 중인 아티스트
    public let nowPlaying: String?

    public var id: String { return stageID }

    public init(
      stageID: String,
      name: String,
      x: Double,
      y: Double,
      width: Double,
      nowPlaying: String?
    ) {
      self.stageID = stageID
      self.name = name
      self.x = x
      self.y = y
      self.width = width
      self.nowPlaying = nowPlaying
    }
  }
}
