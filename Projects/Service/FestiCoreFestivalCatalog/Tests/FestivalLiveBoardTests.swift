import FestiCoreDeviceInterface
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import FestiCoreFestivalCatalog

@Suite("축제 라이브 보드 통신")
struct FestivalLiveBoardTests {
  @Test("라이브 상태와 공개 프로필을 합쳐 크루·팔로우·활성 깃발을 반환한다")
  func mapsLiveBoard() async throws {
    let client = LiveBoardStubClient(responses: [
      "api/v1/festivals/fst_test/live": #"{"code":"SUCCESS","data":{"festivalId":"fst_test","activeFlags":[{"flagId":"flg_a","status":"active","zoneId":"A","activity":"sing"}],"me":{"following":["flg_a","flg_b"],"crew":{"id":"crw_a","name":"우리 크루","members":[{"userId":"usr_a","nickname":"서원지","state":"ready","zoneId":"B"}]}}}}"#,
      "api/v1/festivals/fst_test/flags": #"{"code":"SUCCESS","data":{"items":[{"id":"flg_a","name":"첫 깃발","thumbUrl":"/image/a"},{"id":"flg_b","name":"두 번째 깃발","thumbUrl":null}]}}"#,
    ])
    let service = NetworkFestivalLiveBoardService(
      client: client,
      device: LiveBoardStubDevice(),
      baseURL: URL(string: "https://festicore-dev.up.railway.app")
    )

    let board = try await service.refresh(for: "fst_test")

    #expect(board.activeFlags.map(\.name) == ["첫 깃발"])
    #expect(board.activeFlags.first?.thumbnailURL?.absoluteString ==
      "https://festicore-dev.up.railway.app/image/a")
    #expect(board.followedFlags.map(\.name) == ["첫 깃발", "두 번째 깃발"])
    #expect(board.crew?.members.first?.nickname == "서원지")
    let sentDeviceID = await client.liveDeviceID
    #expect(sentDeviceID == "00000000-0000-4000-8000-000000000001")
  }

  @Test("경로에 사용할 수 없는 축제 ID는 전송 전에 거부한다")
  func rejectsUnsafeFestivalID() async {
    let service = NetworkFestivalLiveBoardService(
      client: LiveBoardStubClient(responses: [:]),
      device: LiveBoardStubDevice(),
      baseURL: nil
    )
    await #expect(throws: FestivalLiveBoardError.self) {
      try await service.refresh(for: "../admin")
    }
  }
}

private struct LiveBoardStubDevice: DeviceRegistrationService {
  func register(_: DeviceRegistrationMetadata) async throws -> DeviceAuthorization {
    throw FestivalLiveBoardError.deviceNotRegistered
  }

  func authorization() async throws -> DeviceAuthorization? {
    .init(deviceID: "00000000-0000-4000-8000-000000000001", bearerToken: "device-token")
  }
}

private actor LiveBoardStubClient: FestiCoreRequestClient {
  private let responses: [String: String]
  private(set) var liveDeviceID: String?

  init(responses: [String: String]) { self.responses = responses }

  func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _: R, as _: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    throw .request(.invalidURL)
  }

  func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    if request.path.hasSuffix("/live") {
      liveDeviceID = request.headers.value(for: "X-Device-Id")
    }
    guard let value = responses[request.path],
          let result = try? JSONDecoder().decode(R.Response.self, from: Data(value.utf8)) else {
      throw .request(.invalidURL)
    }
    return result
  }

  func sendResponse<R: FestiCoreDataRequest>(
    _: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.invalidURL)
  }
}
