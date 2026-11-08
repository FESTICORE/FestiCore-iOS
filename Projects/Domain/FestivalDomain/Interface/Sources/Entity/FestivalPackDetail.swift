//
//  FestivalPackDetail.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 기기에 받은 팩의 가는 길·준비물·반입 금지 정보
public struct FestivalPackDetail: Equatable, Sendable {
  public let pack: FestivalReceivedPack
  public let directions: Directions
  public let checklist: [ChecklistItem]
  public let rules: [String]
  /// 팩 전체 출처
  public let source: Source?

  public init(
    pack: FestivalReceivedPack,
    directions: Directions = Directions(),
    checklist: [ChecklistItem] = [],
    rules: [String] = [],
    source: Source? = nil
  ) {
    self.pack = pack
    self.directions = directions
    self.checklist = checklist
    self.rules = rules
    self.source = source
  }

  public struct Directions: Equatable, Sendable {
    /// 서버가 적은 그대로의 마지막 셔틀·막차 시각
    public let lastShuttleAt: String?
    public let lastTrainAt: String?
    public let shuttle: Section?
    public let transit: Section?
    public let parking: Section?
    /// 운영팀 추천 메모
    public let memo: String?
    public let naverMapURL: URL?
    public let kakaoMapURL: URL?
    /// 출처를 확인한 축제 장소 좌표. 역·정류장을 이름으로 찾을 때 기준 위치로 쓴다.
    public let venueLocation: Coordinate?
    public let source: Source?

    public init(
      lastShuttleAt: String? = nil,
      lastTrainAt: String? = nil,
      shuttle: Section? = nil,
      transit: Section? = nil,
      parking: Section? = nil,
      memo: String? = nil,
      naverMapURL: URL? = nil,
      kakaoMapURL: URL? = nil,
      venueLocation: Coordinate? = nil,
      source: Source? = nil
    ) {
      self.lastShuttleAt = lastShuttleAt
      self.lastTrainAt = lastTrainAt
      self.shuttle = shuttle
      self.transit = transit
      self.parking = parking
      self.memo = memo
      self.naverMapURL = naverMapURL
      self.kakaoMapURL = kakaoMapURL
      self.venueLocation = venueLocation
      self.source = source
    }

    /// 보여 줄 가는 길 정보가 하나도 없는지
    public var isEmpty: Bool {
      lastShuttleAt == nil && lastTrainAt == nil && shuttle == nil && transit == nil
        && parking == nil && memo == nil && naverMapURL == nil && kakaoMapURL == nil
    }
  }

  public struct Section: Equatable, Sendable {
    public let body: String?
    public let links: [Link]
    /// 대중교통의 가까운 역 이름
    public let stationName: String?
    /// 셔틀 정류장 이름
    public let stopName: String?
    public let walkMinutes: Int?
    /// 서버가 준 역·정류장 좌표. 없으면 이름으로 찾는다.
    public let location: Coordinate?

    public init(
      body: String?,
      links: [Link] = [],
      stationName: String? = nil,
      stopName: String? = nil,
      walkMinutes: Int? = nil,
      location: Coordinate? = nil
    ) {
      self.body = body
      self.links = links
      self.stationName = stationName
      self.stopName = stopName
      self.walkMinutes = walkMinutes
      self.location = location
    }
  }

  /// 위도·경도 한 지점
  public struct Coordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(
      latitude: Double,
      longitude: Double
    ) {
      self.latitude = latitude
      self.longitude = longitude
    }
  }

  public struct Link: Equatable, Sendable {
    public let label: String
    public let url: URL

    public init(label: String, url: URL) {
      self.label = label
      self.url = url
    }
  }

  public struct ChecklistItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    /// 운영팀이 정한 필수 항목. 지울 수 없다.
    public let required: Bool
    public let note: String?

    public init(id: String, label: String, required: Bool = false, note: String? = nil) {
      self.id = id
      self.label = label
      self.required = required
      self.note = note
    }
  }

  public struct Source: Equatable, Sendable {
    public let name: String
    public let verifiedAt: Date?

    public init(name: String, verifiedAt: Date?) {
      self.name = name
      self.verifiedAt = verifiedAt
    }
  }
}
