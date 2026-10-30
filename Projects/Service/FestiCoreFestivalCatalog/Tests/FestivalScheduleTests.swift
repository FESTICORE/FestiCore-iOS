@testable import FestiCoreFestivalCatalog
import FestiCoreNetworkInterface
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalScheduleTests {
  @Test
  func replaceSendsWholeScheduleWithMillisecondClientAt() async throws {
    let client = ScheduleStubClient(put: .success(#"{"code":"SUCCESS","data":{"setIds":["set_1"]}}"#))
    let service = NetworkFestivalScheduleService(client: client)
    // 2026-08-07 10:00:00.250 KST
    let clientAt = Date(timeIntervalSince1970: 1_786_064_400.25)

    let schedule = try await service.replace(festivalID: "fst_a", setIDs: ["set_1"], clientAt: clientAt)

    #expect(schedule.setIDs == ["set_1"])
    #expect(await client.paths == ["PUT api/v1/me/schedule/fst_a"])
    #expect(await client.putBodies == [.init(setIds: ["set_1"], clientAt: "2026-08-07T10:00:00.250+09:00")])
  }

  @Test
  func staleReplaceReturnsCurrentServerSchedule() async throws {
    let client = ScheduleStubClient(
      put: .failure(.response(ResponseError(httpStatus: 409, code: "STATUS_STALE"))),
      get: .success(#"{"code":"SUCCESS","data":{"setIds":["set_2"],"updatedAt":null}}"#)
    )
    let service = NetworkFestivalScheduleService(client: client)

    await #expect(throws: FestivalScheduleError.stale(.init(setIDs: ["set_2"]))) {
      try await service.replace(festivalID: "fst_a", setIDs: ["set_1"], clientAt: Date())
    }
    #expect(await client.paths == ["PUT api/v1/me/schedule/fst_a", "GET api/v1/me/schedule/fst_a"])
  }

  @Test(arguments: [
    (FestiCoreNetworkError.response(ResponseError(httpStatus: 401)), FestivalScheduleError.unauthorized),
    (.response(ResponseError(httpStatus: 400, code: "VALIDATION")), .rejected),
    (.response(ResponseError(httpStatus: 429)), .unavailable),
    (.response(ResponseError(httpStatus: 503)), .unavailable),
    (.request(.invalidURL), .unavailable),
  ])
  func fetchErrorsAreMapped(networkError: FestiCoreNetworkError, expected: FestivalScheduleError) async {
    let service = NetworkFestivalScheduleService(client: ScheduleStubClient(get: .failure(networkError)))

    await #expect(throws: expected) {
      try await service.fetch(festivalID: "fst_a")
    }
  }

  @Test
  func invalidFestivalIDIsRejectedWithoutRequest() async {
    let client = ScheduleStubClient()
    let service = NetworkFestivalScheduleService(client: client)

    await #expect(throws: FestivalScheduleError.rejected) {
      try await service.fetch(festivalID: "../admin")
    }
    #expect(await client.paths.isEmpty)
  }
}

private actor ScheduleStubClient: FestiCoreRequestClient {
  private let put: Result<String, FestiCoreNetworkError>
  private let get: Result<String, FestiCoreNetworkError>
  private(set) var paths: [String] = []
  private(set) var putBodies: [SchedulePutRequest.Body] = []

  init(
    put: Result<String, FestiCoreNetworkError> = .failure(.request(.invalidURL)),
    get: Result<String, FestiCoreNetworkError> = .failure(.request(.invalidURL))
  ) {
    self.put = put
    self.get = get
  }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _: R, as _: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    throw .request(.invalidURL)
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    paths.append("\(request.method.rawValue) \(request.path)")
    if let body = (request as? SchedulePutRequest)?.body {
      putBodies.append(body)
    }
    let json = try (request.method == .put ? put : get).get()
    guard let response = try? JSONDecoder().decode(R.Response.self, from: Data(json.utf8)) else {
      throw .request(.invalidURL)
    }
    return response
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }
}
