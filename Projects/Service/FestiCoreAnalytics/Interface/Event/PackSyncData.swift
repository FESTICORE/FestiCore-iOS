//
//  PackSyncData.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

public enum AnalyticsPackSyncResult: String, Sendable {
  case updated
  case notModified = "not_modified"
  case failed
}

public struct PackSyncData: Equatable, Sendable {
  public let festivalID: String
  public let result: AnalyticsPackSyncResult

  public init(festivalID: String, result: AnalyticsPackSyncResult) {
    self.festivalID = festivalID
    self.result = result
  }
}
