//
//  TimetableLineupDay.swift
//  TimetableDomainInterface
//
//  Created by FestiCore on 10/30/26.
//

import Foundation

/// 시간표 공개 전에 보여 줄 날짜별 라인업
public struct TimetableLineupDay: Equatable, Identifiable, Sendable {
  public let id: String
  public var title: String
  public var artists: [String]

  public init(
    id: String,
    title: String,
    artists: [String]
  ) {
    self.id = id
    self.title = title
    self.artists = artists
  }
}
