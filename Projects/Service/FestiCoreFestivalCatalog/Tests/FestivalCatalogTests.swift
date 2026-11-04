import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import FestiCoreFestivalCatalog

@Suite("축제 목록 오프라인 복구")
struct FestivalCatalogTests {
  @Test("목록 페이지를 10개 단위 커서로 요청하고 받은 페이지를 캐시에 누적한다")
  func loadsTenItemPages() async throws {
    let cacheURL = temporaryCacheURL()
    let client = ScriptClient(pages: [
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_a","name":"첫 축제","packVersion":1}],"nextCursor":"cursor-a"}}"#,
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_b","name":"둘째 축제","packVersion":1}],"nextCursor":null}}"#
    ])
    let service = NetworkFestivalCatalogService(
      client: client,
      cacheURL: cacheURL
    )

    let first = try await service.page(
      after: nil,
      limit: 10
    )
    let second = try await service.page(
      after: first.nextCursor,
      limit: 10
    )

    #expect(first.items.map(\.id) == ["fst_a"])
    #expect(second.items.map(\.id) == ["fst_b"])
    #expect(second.nextCursor == nil)
    #expect(await client.requests() == ["nil/10", "cursor-a/10"])
    #expect(try await service.cachedFestivals().map(\.id) == ["fst_a", "fst_b"])
  }

  @Test("새 목록의 모든 페이지를 받기 전에는 기존 전체 오프라인 캐시를 유지한다")
  func keepsCompleteCacheUntilLastPage() async throws {
    let cacheURL = temporaryCacheURL()
    let existing = NetworkFestivalCatalogService(
      client: ScriptClient(pages: [
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_old_a","name":"이전 첫 축제","packVersion":1},{"id":"fst_old_b","name":"이전 둘째 축제","packVersion":1}],"nextCursor":null}}"#
    ]),
      cacheURL: cacheURL
    )
    _ = try await existing.refresh()
    let updated = NetworkFestivalCatalogService(
      client: ScriptClient(pages: [
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_new_a","name":"새 첫 축제","packVersion":1}],"nextCursor":"cursor-a"}}"#,
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_new_b","name":"새 둘째 축제","packVersion":1}],"nextCursor":null}}"#
    ]),
      cacheURL: cacheURL
    )

    let first = try await updated.page(
      after: nil,
      limit: 10
    )
    #expect(first.items.map(\.id) == ["fst_new_a"])
    #expect(try await updated.cachedFestivals().map(\.id) == ["fst_old_a", "fst_old_b"])
    let offlineDuringPaging = NetworkFestivalCatalogService(
      client: ScriptClient(pages: []),
      cacheURL: cacheURL
    )
    #expect(try await offlineDuringPaging.cachedFestivals().map(\.id) == ["fst_old_a", "fst_old_b"])
    _ = try await updated.page(
      after: first.nextCursor,
      limit: 10
    )
    #expect(try await updated.cachedFestivals().map(\.id) == ["fst_new_a", "fst_new_b"])
    let offlineAfterPaging = NetworkFestivalCatalogService(
      client: ScriptClient(pages: []),
      cacheURL: cacheURL
    )
    #expect(try await offlineAfterPaging.cachedFestivals().map(\.id) == ["fst_new_a", "fst_new_b"])
  }

  @Test("다음 페이지 요청이 실패하면 첫 페이지를 보여 준 뒤에도 전체 오프라인 캐시를 보존한다")
  func failedNextPagePreservesCompleteCache() async throws {
    let cacheURL = temporaryCacheURL()
    let existing = NetworkFestivalCatalogService(
      client: ScriptClient(pages: [
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_old_a","name":"이전 첫 축제","packVersion":1},{"id":"fst_old_b","name":"이전 둘째 축제","packVersion":1}],"nextCursor":null}}"#
    ]),
      cacheURL: cacheURL
    )
    _ = try await existing.refresh()

    let updated = NetworkFestivalCatalogService(
      client: ScriptClient(pages: [
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_new_a","name":"새 첫 축제","packVersion":1}],"nextCursor":"cursor-a"}}"#,
      #"{"code":"FAIL","message":"Unavailable","data":{"items":[],"nextCursor":null}}"#
    ]),
      cacheURL: cacheURL
    )
    let first = try await updated.page(
      after: nil,
      limit: 10
    )
    #expect(first.items.map(\.id) == ["fst_new_a"])
    await #expect(throws: FestivalCatalogError.self) {
      try await updated.page(
        after: first.nextCursor,
        limit: 10
      )
    }

    let offline = NetworkFestivalCatalogService(
      client: ScriptClient(pages: []),
      cacheURL: cacheURL
    )
    #expect(try await offline.cachedFestivals().map(\.id) == ["fst_old_a", "fst_old_b"])
  }

  @Test("페이지를 끝까지 읽고 재시작 후 저장 목록을 반환한다")
  func paginatesAndRestores() async throws {
    let cacheURL = temporaryCacheURL()
    let client = ScriptClient(pages: [
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_a","name":"첫 축제","packVersion":1,"thumbUrl":null}],"nextCursor":"cursor-a"}}"#,
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_b","name":"두 번째 축제","packVersion":0,"status":"discovered"}],"nextCursor":null}}"#
    ])
    let online = NetworkFestivalCatalogService(client: client, cacheURL: cacheURL)
    #expect(try await online.refresh().map(\.id) == ["fst_a", "fst_b"])
    let offline = NetworkFestivalCatalogService(client: ScriptClient(pages: []), cacheURL: cacheURL)
    #expect(try await offline.cachedFestivals().map(\.id) == ["fst_a", "fst_b"])
  }

  @Test("중복 커서 실패는 이전 정상 캐시를 덮어쓰지 않는다")
  func repeatedCursorPreservesCache() async throws {
    let cacheURL = temporaryCacheURL()
    let good = NetworkFestivalCatalogService(client: ScriptClient(pages: [
      #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_saved","name":"저장된 축제","packVersion":2}],"nextCursor":null}}"#
    ]), cacheURL: cacheURL)
    _ = try await good.refresh()

    let broken = NetworkFestivalCatalogService(client: ScriptClient(pages: [
      #"{"code":"SUCCESS","message":"OK","data":{"items":[],"nextCursor":"same"}}"#,
      #"{"code":"SUCCESS","message":"OK","data":{"items":[],"nextCursor":"same"}}"#
    ]), cacheURL: cacheURL)
    await #expect(throws: FestivalCatalogError.self) { try await broken.refresh() }
    #expect(try await broken.cachedFestivals().map(\.id) == ["fst_saved"])
  }

  @Test("상대 이미지 경로는 API 호스트에 붙이고 위험한 스킴은 제외한다")
  func resolvesRelativeImageURL() async throws {
    let service = NetworkFestivalCatalogService(
      client: ScriptClient(pages: [
        #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_a","name":"축제","packVersion":1,"thumbUrl":"/api/v1/festivals/images/poster"}],"nextCursor":null}}"#
      ]),
      cacheURL: temporaryCacheURL(),
      baseURL: URL(string: "https://festicore-dev.up.railway.app")
    )
    #expect(try await service.refresh().first?.thumbnailURL?.absoluteString ==
      "https://festicore-dev.up.railway.app/api/v1/festivals/images/poster")
    #expect(service.imageURL(for: "javascript:alert(1)") == nil)
    #expect(service.imageURL(for: "http://example.com/poster.jpg") == nil)
    #expect(FestivalImageURLResolver(baseURL: URL(string: "http://example.com"))
      .resolve("/poster.jpg") == nil)
  }

  @Test("네트워크와 저장된 목록의 위험한 썸네일 URL은 제외한다")
  func rejectsUnsafeItemThumbnailOnRefreshAndCache() async throws {
    let cacheURL = temporaryCacheURL()
    let online = NetworkFestivalCatalogService(
      client: ScriptClient(pages: [
        #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_a","name":"축제","packVersion":1,"thumbUrl":"javascript:alert(1)"}],"nextCursor":null}}"#
      ]),
      cacheURL: cacheURL,
      baseURL: URL(string: "https://festicore-dev.up.railway.app")
    )
    #expect(try await online.refresh().first?.thumbnailURL == nil)

    let offline = NetworkFestivalCatalogService(
      client: ScriptClient(pages: []), cacheURL: cacheURL,
      baseURL: URL(string: "https://festicore-dev.up.railway.app")
    )
    #expect(try await offline.cachedFestivals().first?.thumbnailURL == nil)
  }

  @Test("기본 카탈로그 이미지 URL도 HTTPS만 허용한다")
  func defaultImageURLRejectsUnsafeSchemes() {
    let service = DefaultImageCatalogService()
    #expect(service.imageURL(for: "https://example.com/poster.jpg") != nil)
    #expect(service.imageURL(for: "http://example.com/poster.jpg") == nil)
    #expect(service.imageURL(for: "file:///private/poster.jpg") == nil)
    #expect(service.imageURL(for: "javascript:alert(1)") == nil)
  }

  @Test("이전 버전 캐시의 thumbUrl을 읽어 포스터를 복구한다")
  func restoresExistingCatalogCache() async throws {
    let cacheURL = temporaryCacheURL()
    try FileManager.default.createDirectory(
      at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try Data(#"[{"id":"fst_saved","name":"저장된 축제","thumbUrl":"/api/v1/festivals/images/poster","packVersion":2}]"#.utf8)
      .write(to: cacheURL)
    let service = NetworkFestivalCatalogService(
      client: ScriptClient(pages: []), cacheURL: cacheURL,
      baseURL: URL(string: "https://festicore-dev.up.railway.app")
    )
    #expect(try await service.cachedFestivals().first?.thumbnailURL?.absoluteString ==
      "https://festicore-dev.up.railway.app/api/v1/festivals/images/poster")
  }

  @Test("아티스트 공연 정보가 네트워크 응답에서 캐시로 유지된다")
  func restoresArtistProjection() async throws {
    let cacheURL = temporaryCacheURL()
    let json = #"{"code":"SUCCESS","message":"OK","data":{"items":[{"id":"fst_a","name":"축제","packVersion":1,"artists":[{"name":"아티스트","performances":[{"startsAt":"2026-11-05T10:00:00.000Z","date":"2026-11-05","stageName":"메인"}]}]}],"nextCursor":null}}"#
    let online = NetworkFestivalCatalogService(client: ScriptClient(pages: [json]), cacheURL: cacheURL)
    let refreshed = try await online.refresh()
    let offline = NetworkFestivalCatalogService(client: ScriptClient(pages: []), cacheURL: cacheURL)
    #expect(try await offline.cachedFestivals().first?.artists == refreshed.first?.artists)
    #expect(refreshed.first?.artists?.first?.performances.first?.stageName == "메인")
  }

  private func temporaryCacheURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("festival-catalog-tests-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("catalog.json")
  }
}

private struct DefaultImageCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] { [] }
  func refresh() async throws -> [FestivalCatalogItem] { [] }
}

private actor ScriptClient: FestiCoreRequestClient {
  private var pages: [Data]
  private var requested: [String] = []

  init(pages: [String]) { self.pages = pages.map { Data($0.utf8) } }

  func requests() -> [String] { return requested }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    Issue.record("사용하지 않는 요청")
    throw .request(.invalidURL)
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    if let request = request as? FestivalListRequest {
      requested.append("\(request.after ?? "nil")/\(request.limit)")
    }
    guard !pages.isEmpty else {
      Issue.record("예상하지 않은 페이지 요청")
      throw .request(.invalidURL)
    }
    let data = pages.removeFirst()
    do {
      return try JSONDecoder().decode(R.Response.self, from: data)
    } catch {
      Issue.record("잘못된 테스트 데이터: \(error)")
      throw .decoding(.failed(error))
    }
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    Issue.record("사용하지 않는 요청")
    throw .request(.invalidURL)
  }
}
