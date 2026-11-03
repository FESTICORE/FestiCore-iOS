//
//  NoticeSummary.swift
//  NoticeDomainInterface
//

import Foundation

public struct NoticeSummary: Equatable, Sendable {
  public let id: String
  public let title: String
  public let publishedAt: Date

  public init(id: String, title: String, publishedAt: Date) {
    self.id = id
    self.title = title
    self.publishedAt = publishedAt
  }
}
