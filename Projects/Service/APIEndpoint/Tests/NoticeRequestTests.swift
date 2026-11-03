//
//  NoticeRequestTests.swift
//  APIEndpoint
//

import APIEndpoint
import FestiCoreNetworkInterface
import Foundation
import Testing

@Suite("공지 요청 계약")
struct NoticeRequestTests {
  private let baseURL = URL(string: "https://festicore.test")!

  @Test func publicList() throws {
    let endpoint = NoticeRequest.list
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.absoluteString == "https://festicore.test/api/v1/notices")
    #expect(request.httpMethod == "GET")
    #expect(request.httpBody == nil)
    #expect(endpoint.authorization == .none)
    #expect(endpoint.parameters == nil)
    #expect(endpoint.maxRetryAttempts == 1)
  }

  @Test func publicDetail() throws {
    let endpoint = NoticeRequest.detail(id: "2c75c8de-517d-4611-9c51-b4ff804dd597")
    let request = try endpoint.asURLRequest(baseURL: baseURL)

    #expect(request.url?.absoluteString == "https://festicore.test/api/v1/notices/2c75c8de-517d-4611-9c51-b4ff804dd597")
    #expect(request.httpMethod == "GET")
    #expect(request.httpBody == nil)
    #expect(endpoint.authorization == .none)
    #expect(endpoint.parameters == nil)
    #expect(endpoint.maxRetryAttempts == 1)
  }
}
