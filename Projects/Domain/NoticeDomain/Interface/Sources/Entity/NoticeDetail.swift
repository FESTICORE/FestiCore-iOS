//
//  NoticeDetail.swift
//  NoticeDomainInterface
//

public struct NoticeDetail: Equatable, Sendable {
  public let id: String
  public let title: String
  public let content: String
  public let publishedAt: String

  public init(id: String, title: String, content: String, publishedAt: String) {
    self.id = id
    self.title = title
    self.content = content
    self.publishedAt = publishedAt
  }
}
