//
//  NoticeDTO+Mapper.swift
//  NoticeDomain
//

import FestiCoreUtility
import NoticeDomainInterface

extension NoticeSummaryDTO {
  func toDomain() throws -> NoticeSummary {
    guard let date = publishedAt.isoDate else { throw NoticeError.invalidResponse }
    return NoticeSummary(id: id, title: title, publishedAt: date)
  }
}

extension NoticeDetailDataDTO {
  func toDomain() throws -> NoticeDetail {
    guard let date = publishedAt.isoDate else { throw NoticeError.invalidResponse }
    return NoticeDetail(id: id, title: title, content: content, publishedAt: date)
  }
}
