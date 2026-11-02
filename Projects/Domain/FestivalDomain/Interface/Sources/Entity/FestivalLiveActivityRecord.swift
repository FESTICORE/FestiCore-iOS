//
//  FestivalLiveActivityRecord.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Foundation

public enum FestivalLiveActivityPhase: String, Equatable, Sendable {
  case upcoming
  case ongoing
  case finished
}

public struct FestivalLiveActivityRecord: Equatable, Sendable {
  public let id: String
  public let festivalID: String
  public let phase: FestivalLiveActivityPhase
  public let startDate: Date
  public let endDate: Date?

  public init(
    id: String,
    festivalID: String,
    phase: FestivalLiveActivityPhase,
    startDate: Date,
    endDate: Date?
  ) {
    self.id = id
    self.festivalID = festivalID
    self.phase = phase
    self.startDate = startDate
    self.endDate = endDate
  }
}
