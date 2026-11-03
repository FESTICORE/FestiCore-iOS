//
//  NoticeDetail.swift
//  NoticeDomainInterface
//

import Foundation

public struct NoticeDetail: Equatable, Sendable {
  public let id: String
  public let title: String
  public let content: String
  public let publishedAt: Date

  public init(id: String, title: String, content: String, publishedAt: Date) {
    self.id = id
    self.title = title
    self.content = content
    self.publishedAt = publishedAt
  }
}
