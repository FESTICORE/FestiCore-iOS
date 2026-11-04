import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import FestiCoreFestivalCatalog

struct FestivalDetailTests {
  @Test func detailRequestIsPublicGet() {
    let request = FestivalDetailRequest(festivalID: "fst_1")
    #expect(request.path == "api/v1/festivals/fst_1")
    #expect(request.method == .get)
    #expect(request.authorization == .none)
    #expect(request.parameters == nil)
  }

  @Test func publicDetailLoadsTimetableWithoutWritingCatalogCache() async throws {
    let client = DetailClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"fst_1","name":"축제","venue":"광장","packVersion":2,"days":[{"date":"2026-11-05"}],"stages":[{"id":"main","name":"메인"}],"timetable":[{"id":"set_1","artist":"가수","stageId":"main","startsAt":"2026-11-05T10:00:00Z"}]}}"#)
    let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("catalog.json")
    let service = NetworkFestivalCatalogService(
      client: client,
      cacheURL: cacheURL
    )

    let detail = try await service.festivalDetail(for: "fst_1")

    #expect(detail.id == "fst_1")
    #expect(detail.performances.first?.id == "set_1")
    #expect(await client.requestedPath == "api/v1/festivals/fst_1")
    #expect(try await service.cachedFestivals().isEmpty)
  }

  @Test func rejectsMismatchedDetailID() async throws {
    let client = DetailClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"other"}}"#)
    let service = NetworkFestivalCatalogService(
      client: client,
      cacheURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    )
    await #expect(throws: FestivalCatalogError.self) {
      _ = try await service.festivalDetail(for: "fst_1")
    }
  }

  @Test func rejectsUnsafeFestivalIDBeforeSending() async throws {
    let client = DetailClient(json: #"{"code":"SUCCESS","message":"OK","data":{"id":"fst"}}"#)
    let service = NetworkFestivalCatalogService(
      client: client,
      cacheURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    )
    await #expect(throws: FestivalCatalogError.self) {
      _ = try await service.festivalDetail(for: "fst/other")
    }
    #expect(await client.requestedPath == nil)
  }
}

private actor DetailClient: FestiCoreRequestClient {
  let json: Data
  var requestedPath: String?

  init(json: String) { self.json = Data(json.utf8) }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    throw .request(.invalidURL)
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    requestedPath = request.path
    do {
      return try JSONDecoder().decode(
        R.Response.self,
        from: json
      )
    } catch {
      throw .decoding(.failed(error))
    }
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }
}
