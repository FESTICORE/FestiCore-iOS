//
//  NoticeResponseDTO.swift
//  NoticeDomain
//

import FestiCoreNetworkInterface

typealias NoticeListResponseDTO = BaseResponseDTO<NoticeListDataDTO>
typealias NoticeDetailResponseDTO = BaseResponseDTO<NoticeDetailDataDTO>

struct NoticeListDataDTO: Decodable, Sendable, Equatable {
  let items: [NoticeSummaryDTO]
}

struct NoticeSummaryDTO: Decodable, Sendable, Equatable {
  let id: String
  let title: String
  let publishedAt: String
}

struct NoticeDetailDataDTO: Decodable, Sendable, Equatable {
  let id: String
  let title: String
  let content: String
  let publishedAt: String
}
