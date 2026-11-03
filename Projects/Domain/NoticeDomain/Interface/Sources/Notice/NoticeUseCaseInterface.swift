//
//  NoticeUseCaseInterface.swift
//  NoticeDomainInterface
//

import Dependencies

public protocol NoticeUseCaseInterface: Sendable {
  func notices() async throws -> [NoticeSummary]
  func notice(id: String) async throws -> NoticeDetail
}

public enum NoticeUseCaseDependency: TestDependencyKey {
  public static var testValue: any NoticeUseCaseInterface { MockNoticeUseCase() }
  public static var previewValue: any NoticeUseCaseInterface { testValue }
}

public extension DependencyValues {
  var noticeUseCase: any NoticeUseCaseInterface {
    get { self[NoticeUseCaseDependency.self] }
    set { self[NoticeUseCaseDependency.self] = newValue }
  }
}
