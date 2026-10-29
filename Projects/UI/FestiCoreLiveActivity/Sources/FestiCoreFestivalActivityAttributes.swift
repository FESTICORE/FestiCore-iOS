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

    public init(phase: Phase, startDate: Date, endDate: Date? = nil) {
      self.phase = phase
      self.startDate = startDate
      self.endDate = endDate
    }
  }

  public var festivalID: String
  public var festivalName: String

  public init(festivalID: String, festivalName: String) {
    self.festivalID = festivalID
    self.festivalName = festivalName
  }
}
