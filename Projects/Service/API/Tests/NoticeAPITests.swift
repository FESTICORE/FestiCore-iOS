//
//  NoticeAPITests.swift
//  API
//

import API
import Testing

@Suite("공지 API 경로")
struct NoticeAPITests {
  @Test func paths() {
    #expect(FestiCoreDomain.notices.path == "api/v1/notices")
    #expect(NoticeAPI.list.path == "api/v1/notices")
    #expect(NoticeAPI.detail(id: "notice-id").path == "api/v1/notices/notice-id")
  }
}
