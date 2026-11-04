import APIEndpoint
import FestiCoreNetworkInterface
import Foundation
import Testing

@Suite("크루 생성 요청 계약")
struct CrewRequestTests {
  @Test func createUsesAuthenticatedPostAndOmitsAbsentNickname() throws {
    let sessionID = UUID()
    let endpoint = CrewRequest.create(
      body: CrewCreateBody(
        festivalId: "fst_1",
        name: "친구들"
      ),
      sessionID: sessionID
    )
    let request = try endpoint.asURLRequest(baseURL: URL(string: "https://festicore.test")!)
    let data = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

    #expect(request.url?.path == "/api/v1/crews")
    #expect(request.httpMethod == "POST")
    #expect(endpoint.authorization == .sessionBound(sessionID))
    #expect(endpoint.maxRetryAttempts == 0)
    #expect(body == ["festivalId": "fst_1", "name": "친구들"])
  }

  @Test func createIncludesProvidedNickname() throws {
    let endpoint = CrewRequest.create(
      body: CrewCreateBody(
        festivalId: "fst_1",
        name: "친구들",
        nickname: "로이"
      ),
      sessionID: UUID()
    )
    let request = try endpoint.asURLRequest(baseURL: URL(string: "https://festicore.test")!)
    let data = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(body["nickname"] == "로이")
  }
}
