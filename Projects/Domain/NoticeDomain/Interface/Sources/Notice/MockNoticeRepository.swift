//
//  MockNoticeRepository.swift
//  NoticeDomainInterface
//

import IssueReporting

public struct MockNoticeRepository: NoticeRepositoryInterface {
  private let list: @Sendable () async throws -> [NoticeSummary]
  private let detail: @Sendable (String) async throws -> NoticeDetail

  public init(
    notices: @escaping @Sendable () async throws -> [NoticeSummary] = {
      reportIssue("noticeRepository 미등록")
      throw NoticeError.unavailable
    },
    notice: @escaping @Sendable (String) async throws -> NoticeDetail = { _ in
      reportIssue("noticeRepository 미등록")
      throw NoticeError.unavailable
    }
  ) {
    list = notices
    detail = notice
  }

  public func notices() async throws -> [NoticeSummary] { try await list() }
  public func notice(id: String) async throws -> NoticeDetail { try await detail(id) }
}
