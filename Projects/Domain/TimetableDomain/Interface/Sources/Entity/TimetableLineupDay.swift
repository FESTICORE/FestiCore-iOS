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
  public var artists: [TimetableLineupArtist]

  public init(
    id: String,
    title: String,
    artists: [TimetableLineupArtist]
  ) {
    self.id = id
    self.title = title
    self.artists = artists
  }
}

/// 라인업에 보여 줄 아티스트 이름과 사진
public struct TimetableLineupArtist: Equatable, Sendable {
  public var name: String
  public var imageURL: URL?

  public init(
    name: String,
    imageURL: URL? = nil
  ) {
    self.name = name
    self.imageURL = imageURL
  }
}
