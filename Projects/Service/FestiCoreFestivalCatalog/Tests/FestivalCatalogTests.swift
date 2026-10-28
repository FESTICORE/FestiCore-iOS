import FestiCoreFestivalCatalogInterface
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import FestiCoreFestivalCatalog

@Suite("축제 목록 오프라인 복구")
struct FestivalCatalogTests {
  @Test("페이지를 끝까지 읽고 재시작 후 저장 목록을 반환한다")
  func paginatesAndRestores() async throws {
    let cacheURL = temporaryCacheURL()
    let client = ScriptClient(pages: [
      #"{"code":"SUCCESS","data":{"items":[{"id":"fst_a","name":"첫 축제","packVersion":1,"thumbUrl":null}],"nextCursor":"cursor-a"}}"#,
      #"{"code":"SUCCESS","data":{"items":[{"id":"fst_b","name":"두 번째 축제","packVersion":0,"status":"discovered"}],"nextCursor":null}}"#
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
      #"{"code":"SUCCESS","data":{"items":[{"id":"fst_saved","name":"저장된 축제","packVersion":2}],"nextCursor":null}}"#
    ]), cacheURL: cacheURL)
    _ = try await good.refresh()

    let broken = NetworkFestivalCatalogService(client: ScriptClient(pages: [
      #"{"code":"SUCCESS","data":{"items":[],"nextCursor":"same"}}"#,
      #"{"code":"SUCCESS","data":{"items":[],"nextCursor":"same"}}"#
    ]), cacheURL: cacheURL)
    await #expect(throws: FestivalCatalogError.self) { try await broken.refresh() }
    #expect(try await broken.cachedFestivals().map(\.id) == ["fst_saved"])
  }

  @Test("상대 이미지 경로는 API 호스트에 붙이고 위험한 스킴은 제외한다")
  func resolvesRelativeImageURL() async throws {
    let service = NetworkFestivalCatalogService(
      client: ScriptClient(pages: [
        #"{"code":"SUCCESS","data":{"items":[{"id":"fst_a","name":"축제","packVersion":1,"thumbUrl":"/api/v1/festivals/images/poster"}],"nextCursor":null}}"#
      ]),
      cacheURL: temporaryCacheURL(),
      baseURL: URL(string: "https://festicore-dev.up.railway.app")
    )
    #expect(try await service.refresh().first?.thumbnailURL?.absoluteString ==
      "https://festicore-dev.up.railway.app/api/v1/festivals/images/poster")
    #expect(service.imageURL(for: "javascript:alert(1)") == nil)
  }

  private func temporaryCacheURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("festival-catalog-tests-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("catalog.json")
  }
}

private actor ScriptClient: FestiCoreRequestClient {
  private var pages: [Data]

  init(pages: [String]) { self.pages = pages.map { Data($0.utf8) } }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R, as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    fatalError("사용하지 않는 요청")
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    guard !pages.isEmpty else { fatalError("예상하지 않은 페이지 요청") }
    let data = pages.removeFirst()
    do { return try JSONDecoder().decode(R.Response.self, from: data) }
    catch { fatalError("잘못된 테스트 데이터: \(error)") }
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    fatalError("사용하지 않는 요청")
  }
}
