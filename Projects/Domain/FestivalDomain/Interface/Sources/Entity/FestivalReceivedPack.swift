//
//  FestivalReceivedPack.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 기기에 받아 둔 축제 팩 요약
public struct FestivalReceivedPack: Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let thumbnailURL: URL?
  /// 기기에 저장된 팩 버전
  public let packVersion: Int
  /// 축제 목록이 알려 준 최신 발행 버전. 목록에 없으면 nil이다.
  public let latestPackVersion: Int?
  /// 서버와 마지막으로 버전을 맞춘 시각
  public let checkedAt: Date?
  /// 저장된 팩 JSON 크기(바이트)
  public let sizeBytes: Int
  /// 자동 받기를 시도했지만 새 버전을 받지 못했는지
  public var autoUpdateFailed: Bool

  public init(
    id: String,
    name: String,
    thumbnailURL: URL? = nil,
    packVersion: Int,
    latestPackVersion: Int? = nil,
    checkedAt: Date? = nil,
    sizeBytes: Int = 0,
    autoUpdateFailed: Bool = false
  ) {
    self.id = id
    self.name = name
    self.thumbnailURL = thumbnailURL
    self.packVersion = packVersion
    self.latestPackVersion = latestPackVersion
    self.checkedAt = checkedAt
    self.sizeBytes = sizeBytes
    self.autoUpdateFailed = autoUpdateFailed
  }

  /// 서버에 더 새 버전이 발행됐는지
  public var hasUpdate: Bool {
    (latestPackVersion ?? packVersion) > packVersion
  }
}
