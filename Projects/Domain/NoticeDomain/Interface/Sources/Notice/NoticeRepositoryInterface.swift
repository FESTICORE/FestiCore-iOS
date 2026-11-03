//
//  NoticeRepositoryInterface.swift
//  NoticeDomainInterface
//

import Dependencies

public protocol NoticeRepositoryInterface: Sendable {
  func notices() async throws -> [NoticeSummary]
  func notice(id: String) async throws -> NoticeDetail
}

public enum NoticeRepositoryDependency: TestDependencyKey {
  public static var testValue: any NoticeRepositoryInterface { MockNoticeRepository() }
  public static var previewValue: any NoticeRepositoryInterface { testValue }
}

public extension DependencyValues {
  var noticeRepository: any NoticeRepositoryInterface {
    get { self[NoticeRepositoryDependency.self] }
    set { self[NoticeRepositoryDependency.self] = newValue }
  }
}
