//
//  NoticeUseCaseImpl.swift
//  NoticeDomain
//

import Dependencies
import NoticeDomainInterface

public struct NoticeUseCaseImpl: NoticeUseCaseInterface {
  @Dependency(\.noticeRepository) private var repository

  public init() {}

  public func notices() async throws -> [NoticeSummary] { try await repository.notices() }
  public func notice(id: String) async throws -> NoticeDetail { try await repository.notice(id: id) }
}
