//
//  NoticeSummary.swift
//  NoticeDomainInterface
//

public struct NoticeSummary: Equatable, Sendable {
  public let id: String
  public let title: String
  public let publishedAt: String

  public init(id: String, title: String, publishedAt: String) {
    self.id = id
    self.title = title
    self.publishedAt = publishedAt
  }
}
