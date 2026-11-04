//
//  NoticeFeatureTests.swift
//  Profile
//

import ComposableArchitecture
import Foundation
import FestiCoreUtility
import NoticeDomainInterface
import Testing
@testable import Profile

@MainActor
struct NoticeFeatureTests {
  @Test func noticeDateUsesSeoulDayAcrossUTCMidnightBoundary() throws {
    let date = try #require(ISO8601DateFormatter().date(from: "2026-11-03T15:30:00Z"))
    #expect(date.formatted(.noticeDay) == "2026.11.04")
  }

  @Test func listLoadsPublishedNoticesAndOpensDetail() async {
    let notices = [NoticeSummary(
      id: "2c75c8de-517d-4611-9c51-b4ff804dd597",
      title: "서비스 안내",
      publishedAt: Date(timeIntervalSince1970: 0)
    )]
    let store = TestStore(initialState: NoticeListFeature.State()) {
      NoticeListFeature()
    } withDependencies: {
      $0.noticeUseCase = StubNoticeUseCase(notices: { notices })
    }

    await store.send(.view(.onAppear)) { $0.load = .loading }
    await store.receive(\.async.fetchNotices)
    await store.receive(\.inner.noticesLoaded) {
      $0.notices = notices
      $0.load = .loaded
    }
    await store.send(.view(.noticeTapped("missing")))
    await store.send(.view(.noticeTapped(notices[0].id))) {
      $0.destination = .detail(.init(id: notices[0].id, title: notices[0].title))
    }
    await store.send(.destination(.presented(.detail(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  @Test func emptyListIsLoadedInsteadOfShowingSkeletonForever() async {
    let store = TestStore(initialState: NoticeListFeature.State()) {
      NoticeListFeature()
    } withDependencies: {
      $0.noticeUseCase = StubNoticeUseCase(notices: { [] })
    }

    await store.send(.view(.onAppear)) { $0.load = .loading }
    await store.receive(\.async.fetchNotices)
    await store.receive(\.inner.noticesLoaded) { $0.load = .loaded }
    await store.send(.view(.onAppear))
  }

  @Test func listFailureCanRetry() async {
    let attempts = LockIsolated(0)
    let store = TestStore(initialState: NoticeListFeature.State()) {
      NoticeListFeature()
    } withDependencies: {
      $0.noticeUseCase = StubNoticeUseCase(notices: {
        let count = attempts.withValue { value -> Int in
          value += 1
          return value
        }
        if count == 1 { throw NoticeTestError.offline }
        return []
      })
    }

    await store.send(.view(.onAppear)) { $0.load = .loading }
    await store.receive(\.async.fetchNotices)
    await store.receive(\.inner.noticesFailed) { $0.load = .failed }
    await store.send(.view(.retryTapped)) { $0.load = .loading }
    await store.receive(\.async.fetchNotices)
    await store.receive(\.inner.noticesLoaded) { $0.load = .loaded }
  }

  @Test func detailLoadsContentAndCanRetryAfterFailure() async {
    let id = "2c75c8de-517d-4611-9c51-b4ff804dd597"
    let detail = NoticeDetail(
      id: id,
      title: "서비스 안내",
      content: "공지 본문",
      publishedAt: Date(timeIntervalSince1970: 0)
    )
    let attempts = LockIsolated(0)
    let store = TestStore(initialState: NoticeDetailFeature.State(id: id, title: detail.title)) {
      NoticeDetailFeature()
    } withDependencies: {
      $0.noticeUseCase = StubNoticeUseCase(notice: { requestedID in
        #expect(requestedID == id)
        let count = attempts.withValue { value -> Int in
          value += 1
          return value
        }
        if count == 1 { throw NoticeTestError.offline }
        return detail
      })
    }

    await store.send(.view(.onAppear)) { $0.load = .loading }
    await store.receive(\.async.fetchNotice)
    await store.receive(\.inner.noticeFailed) { $0.load = .failed }
    await store.send(.view(.retryTapped)) { $0.load = .loading }
    await store.receive(\.async.fetchNotice)
    await store.receive(\.inner.noticeLoaded) {
      $0.detail = detail
      $0.load = .loaded
    }
    await store.send(.view(.backTapped))
    await store.receive(\.delegate.backRequested)
  }
}

private enum NoticeTestError: Error { case offline }

private struct StubNoticeUseCase: NoticeUseCaseInterface {
  var list: @Sendable () async throws -> [NoticeSummary]
  var detail: @Sendable (String) async throws -> NoticeDetail

  init(
    notices: @escaping @Sendable () async throws -> [NoticeSummary] = { [] },
    notice: @escaping @Sendable (String) async throws -> NoticeDetail = { _ in throw NoticeTestError.offline }
  ) {
    list = notices
    detail = notice
  }

  func notices() async throws -> [NoticeSummary] { try await list() }
  func notice(id: String) async throws -> NoticeDetail { try await detail(id) }
}
