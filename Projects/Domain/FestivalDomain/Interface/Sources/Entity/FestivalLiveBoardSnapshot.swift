//
//  FestivalLiveBoardSnapshot.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Foundation

public struct FestivalLiveBoardSnapshot: Equatable, Sendable {
  public struct Flag: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let status: String
    public let zoneID: String?
    public let activity: String?
    public let thumbnailURL: URL?
    public let tags: [String]
    public let updatedAt: Date?
    public let followerCount: Int?
    public let homeZoneID: String?

    public init(
      id: String, name: String, status: String, zoneID: String?, activity: String?,
      thumbnailURL: URL?, tags: [String] = [], updatedAt: Date? = nil,
      followerCount: Int? = nil, homeZoneID: String? = nil
    ) {
      self.id = id
      self.name = name
      self.status = status
      self.zoneID = zoneID
      self.activity = activity
      self.thumbnailURL = thumbnailURL
      self.tags = tags
      self.updatedAt = updatedAt
      self.followerCount = followerCount
      self.homeZoneID = homeZoneID
    }
  }

  public struct Crew: Equatable, Sendable {
    public struct Member: Equatable, Identifiable, Sendable {
      public let id: String
      public let nickname: String
      public let state: String?
      public let zoneID: String?
      public let updatedAt: Date?

      public init(id: String, nickname: String, state: String?, zoneID: String?, updatedAt: Date? = nil) {
        self.id = id
        self.nickname = nickname
        self.state = state
        self.zoneID = zoneID
        self.updatedAt = updatedAt
      }
    }

    public struct GatherRequest: Equatable, Sendable {
      /// 크루원 한 명의 응답. 응답한 순서대로 온다.
      public struct Response: Equatable, Sendable {
        public let userID: String
        public let nickname: String
        public let response: FestivalCrewGatherResponse
        public let respondedAt: Date

        public init(
          userID: String,
          nickname: String,
          response: FestivalCrewGatherResponse,
          respondedAt: Date
        ) {
          self.userID = userID
          self.nickname = nickname
          self.response = response
          self.respondedAt = respondedAt
        }
      }

      /// 응답 API에 쓰는 모여 ID. 이전 서버 응답에는 없다.
      public let id: String?
      public let zoneID: String?
      public let byUserID: String
      public let at: Date
      /// 응답을 받을 수 있는 마지막 시각(보낸 뒤 10분). 이전 서버 응답에는 없다.
      public let expiresAt: Date?
      public let responses: [Response]

      public init(
        id: String? = nil,
        zoneID: String?,
        byUserID: String,
        at: Date,
        expiresAt: Date? = nil,
        responses: [Response] = [],
        summary: Summary? = nil
      ) {
        self.serverSummary = summary
        self.id = id
        self.zoneID = zoneID
        self.byUserID = byUserID
        self.at = at
        self.expiresAt = expiresAt
        self.responses = responses
      }

      /// 응답별 인원
      public struct Summary: Equatable, Sendable {
        public let going: Int
        public let ack: Int

        public init(
          going: Int,
          ack: Int
        ) {
          self.going = going
          self.ack = ack
        }
      }

      /// 서버 요약. 요약이 없던 이전 응답이면 응답 목록으로 센다.
      public var summary: Summary {
        return serverSummary ?? Summary(
          going: responses.filter { $0.response == .going }.count,
          ack: responses.filter { $0.response == .ack }.count
        )
      }

      private let serverSummary: Summary?
    }

    public let id: String
    public let name: String
    public let members: [Member]
    public let ownerID: String?
    public let gatherRequest: GatherRequest?
    public let gatherAvailableAt: Date?

    public init(
      id: String, name: String, members: [Member], ownerID: String? = nil,
      gatherRequest: GatherRequest? = nil, gatherAvailableAt: Date? = nil
    ) {
      self.id = id
      self.name = name
      self.members = members
      self.ownerID = ownerID
      self.gatherRequest = gatherRequest
      self.gatherAvailableAt = gatherAvailableAt
    }
  }

  public let festivalID: String
  public let activeFlags: [Flag]
  public let followedFlags: [Flag]
  public let crew: Crew?
  public let serverAt: Date?
  public let pinnedFlagID: String?
  /// 축제의 공개 깃발 전체. 공개 목록 순서에 라이브 상태를 합친다.
  public let directoryFlags: [Flag]
  /// 이 기기가 라이브 상태를 마지막으로 확인한 시각. 304로 이전 응답을 재사용해도 새로 기록한다.
  public let receivedAt: Date?
  /// 이 축제에서 내가 기수인 깃발 ID(`me.bearerOf`)
  public let bearerFlagIDs: [String]

  public init(
    festivalID: String, activeFlags: [Flag], followedFlags: [Flag], crew: Crew?,
    serverAt: Date? = nil, pinnedFlagID: String? = nil, directoryFlags: [Flag] = [],
    receivedAt: Date? = nil, bearerFlagIDs: [String] = []
  ) {
    self.festivalID = festivalID
    self.activeFlags = activeFlags
    self.followedFlags = followedFlags
    self.crew = crew
    self.serverAt = serverAt
    self.pinnedFlagID = pinnedFlagID
    self.directoryFlags = directoryFlags
    self.receivedAt = receivedAt
    self.bearerFlagIDs = bearerFlagIDs
  }
}

public enum FestivalLiveBoardError: Error, Equatable, Sendable {
  case deviceNotRegistered
  case festivalNotFound
  case invalidFestivalID
  case invalidResponse
  case rateLimited(retryAfter: TimeInterval)
}
