//
//  NoticeDomainTests.swift
//  NoticeDomainTests
//

import Dependencies
import FestiCoreNetworkInterface
import Foundation
import NoticeDomainInterface
import Testing
@testable import NoticeDomain

@Suite("공지 도메인")
struct NoticeDomainTests {
  @Test func listMapsPublishedItemsAndSendsPublicGet() async throws {
    let client = NoticeRecordingClient(json: #"""
      {"code":"SUCCESS","message":"OK","data":{"items":[
        {"id":"2c75c8de-517d-4611-9c51-b4ff804dd597",
         "title":"서비스 안내","publishedAt":"2026-11-04T00:00:00.000Z"}
      ]}}
      """#)
    let repository = withDependencies { $0.networkClient = client } operation: { NoticeRepositoryImpl() }

    let notices = try await repository.notices()
    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/notices")
    #expect(sent.method == "GET")
    #expect(sent.authorization == .none)
    #expect(sent.hasParameters == false)
    let publishedAt = try #require(ISO8601DateFormatter().date(from: "2026-11-04T00:00:00Z"))
    #expect(notices == [NoticeSummary(
      id: "2c75c8de-517d-4611-9c51-b4ff804dd597",
      title: "서비스 안내",
      publishedAt: publishedAt
    )])
  }

  @Test func detailMapsContentAndSendsPublicGet() async throws {
    let id = "2c75c8de-517d-4611-9c51-b4ff804dd597"
    let client = NoticeRecordingClient(json: #"""
      {"code":"SUCCESS","message":"OK","data":{
        "id":"2c75c8de-517d-4611-9c51-b4ff804dd597",
        "title":"서비스 안내","content":"공지 본문",
        "publishedAt":"2026-11-04T00:00:00.000Z"
      }}
      """#)
    let repository = withDependencies { $0.networkClient = client } operation: { NoticeRepositoryImpl() }

    let detail = try await repository.notice(id: id)
    let sent = try #require(await client.last)
    #expect(sent.path == "api/v1/notices/\(id)")
    #expect(sent.method == "GET")
    #expect(sent.authorization == .none)
    let publishedAt = try #require(ISO8601DateFormatter().date(from: "2026-11-04T00:00:00Z"))
    #expect(detail == NoticeDetail(
      id: id,
      title: "서비스 안내",
      content: "공지 본문",
      publishedAt: publishedAt
    ))
  }

  @Test func invalidEnvelopeAndNullableFieldsDoNotProduceDomainContent() async throws {
    let invalidCode = NoticeRecordingClient(json: #"{"code":"ERROR","message":"failure","data":{"items":[]}}"#)
    let repository = withDependencies { $0.networkClient = invalidCode } operation: { NoticeRepositoryImpl() }
    await #expect(throws: NoticeError.invalidResponse) { try await repository.notices() }

    let nullable = Data(#"""
      {"code":"SUCCESS","message":"OK","data":{"items":[
        {"id":"x","title":null,"publishedAt":"2026-11-04T00:00:00.000Z"}
      ]}}
      """#.utf8)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(NoticeListResponseDTO.self, from: nullable) }

    let invalidDate = NoticeRecordingClient(json: #"""
      {"code":"SUCCESS","message":"OK","data":{"items":[
        {"id":"x","title":"공지","publishedAt":"invalid"}
      ]}}
      """#)
    let invalidDateRepository = withDependencies {
      $0.networkClient = invalidDate
    } operation: {
      NoticeRepositoryImpl()
    }
    await #expect(throws: NoticeError.invalidResponse) { try await invalidDateRepository.notices() }
  }

  @Test func useCaseUsesRepositoryAndLiveDependenciesResolve() async throws {
    let expected = NoticeSummary(id: "notice-id", title: "공지", publishedAt: Date(timeIntervalSince1970: 0))
    let useCase = withDependencies {
      $0.noticeRepository = MockNoticeRepository(notices: { [expected] })
    } operation: { NoticeUseCaseImpl() }

    #expect(try await useCase.notices() == [expected])
    #expect(NoticeRepositoryDependency.liveValue is NoticeRepositoryImpl)
    #expect(NoticeUseCaseDependency.liveValue is NoticeUseCaseImpl)
  }
}

private actor NoticeRecordingClient: FestiCoreNetworkClient {
  struct Sent: Sendable {
    let path: String
    let method: String
    let authorization: FestiCoreAuthorization
    let hasParameters: Bool
  }

  let body: Data
  private(set) var last: Sent?

  init(json: String) { body = Data(json.utf8) }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    last = Sent(
      path: request.path,
      method: request.method.rawValue,
      authorization: request.authorization,
      hasParameters: request.parameters != nil
    )
    do {
      return try JSONDecoder().decode(type, from: body)
    } catch {
      throw .decoding(.failed(error))
    }
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.invalidURL)
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }

  func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.invalidURL)
  }

  func upload(_ request: some FestiCoreFileUploadRequest) async throws(FestiCoreNetworkError) {
    throw .request(.invalidURL)
  }
}
