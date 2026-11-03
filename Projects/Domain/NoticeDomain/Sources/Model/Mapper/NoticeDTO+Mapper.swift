//
//  NoticeDTO+Mapper.swift
//  NoticeDomain
//

import NoticeDomainInterface

extension NoticeSummaryDTO {
  func toDomain() -> NoticeSummary {
    NoticeSummary(id: id, title: title, publishedAt: publishedAt)
  }
}

extension NoticeDetailDataDTO {
  func toDomain() -> NoticeDetail {
    NoticeDetail(id: id, title: title, content: content, publishedAt: publishedAt)
  }
}
