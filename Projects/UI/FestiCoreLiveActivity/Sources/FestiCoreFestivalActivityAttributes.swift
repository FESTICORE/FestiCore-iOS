//
//  FestiCoreFestivalActivityAttributes.swift
//  FestiCoreLiveActivity
//
//  Created by FestiCore on 10/23/26.
//

import ActivityKit
import Foundation

public struct FestiCoreFestivalActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable, Sendable {
    public enum Phase: String, Codable, Hashable, Sendable {
      case upcoming
      case ongoing
      case finished
    }

    public var phase: Phase
    public var startDate: Date
    public var endDate: Date?
    /// 서버가 현재 공연 중이라고 확인한 무대. 시작/종료 시각은 타임존이 포함된 ISO 8601 문자열이다.
    public var nowStages: [NowStage]
    /// 로그인 사용자가 저장한 공연 중 아직 시작하지 않은 가장 빠른 공연.
    public var nextMine: NextMine?
    public var pinnedFlag: PinnedFlag?
    public var crewSummary: CrewSummary?
    public var leaveAt: Date?

    public init(
      phase: Phase,
      startDate: Date,
      endDate: Date? = nil,
      nowStages: [NowStage] = [],
      nextMine: NextMine? = nil,
      pinnedFlag: PinnedFlag? = nil,
      crewSummary: CrewSummary? = nil,
      leaveAt: Date? = nil
    ) {
      self.phase = phase
      self.startDate = startDate
      self.endDate = endDate
      self.nowStages = nowStages
      self.nextMine = nextMine
      self.pinnedFlag = pinnedFlag
      self.crewSummary = crewSummary
      self.leaveAt = leaveAt
    }

    public struct NowStage: Codable, Hashable, Sendable {
      public let setId: String
      public let stageId: String
      public let stageName: String?
      public let artist: String
      public let startsAt: String
      public let endsAt: String

      public init(
        setId: String,
        stageId: String,
        stageName: String? = nil,
        artist: String,
        startsAt: String,
        endsAt: String
      ) {
        self.setId = setId
        self.stageId = stageId
        self.stageName = stageName
        self.artist = artist
        self.startsAt = startsAt
        self.endsAt = endsAt
      }
    }

    public struct NextMine: Codable, Hashable, Sendable {
      public let setId: String
      public let stageId: String
      public let stageName: String?
      public let artist: String
      public let startsAt: String

      public init(
        setId: String,
        stageId: String,
        stageName: String? = nil,
        artist: String,
        startsAt: String
      ) {
        self.setId = setId
        self.stageId = stageId
        self.stageName = stageName
        self.artist = artist
        self.startsAt = startsAt
      }
    }

    public struct PinnedFlag: Codable, Hashable, Sendable {
      public enum Status: String, Codable, Hashable, Sendable {
        case active
        case resting
      }

      public let flagId: String
      public let status: Status
      public let zoneId: String?
      public let activity: String?
    }

    public struct CrewSummary: Codable, Hashable, Sendable {
      public let crewId: String
      public let name: String
      public let memberCount: Int
      public let hereCount: Int
      public let gatherZoneId: String?
    }
  }

  public var festivalID: String
  public var festivalName: String

  public init(festivalID: String, festivalName: String) {
    self.festivalID = festivalID
    self.festivalName = festivalName
  }
}
