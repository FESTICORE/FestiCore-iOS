import Dependencies
import Foundation
import Testing
import UserNotificationDomainInterface
@testable import UserNotificationDomain

@Suite("내 알림 도메인")
struct UserNotificationDomainTests {
  @Test func mapsNullableReadDateAndOpaqueCursor() throws {
    let data = Data(#"""
      {"code":"SUCCESS","message":"OK","data":{"items":[
        {"id":"ntf_0123456789abcdef0123456789abcdef","type":"festival.start",
         "festivalId":"fst_2026","title":"시작","body":"곧 시작합니다",
         "createdAt":"2026-11-04T00:00:00.000Z","readAt":null,"route":"/festivals/fst_2026/live"}
      ],"nextCursor":"opaque|cursor"}}
      """#.utf8)
    let response = try JSONDecoder().decode(UserNotificationListResponseDTO.self, from: data)
    let page = try response.data.toDomain()

    #expect(page.nextCursor == "opaque|cursor")
    #expect(page.items.count == 1)
    #expect(page.items[0].festivalID == "fst_2026")
    #expect(page.items[0].readAt == nil)
    #expect(page.items[0].route == "/festivals/fst_2026/live")
  }

  @Test func malformedDatesAndRequiredFieldsFail() throws {
    let item = UserNotificationItemDTO(
      id: "ntf_0123456789abcdef0123456789abcdef", type: "festival.start", festivalId: nil,
      title: "시작", body: "본문", createdAt: "invalid", readAt: nil, route: nil
    )
    #expect(throws: UserNotificationError.invalidResponse) { try item.toDomain() }
    let badReadDate = UserNotificationItemDTO(
      id: item.id, type: item.type, festivalId: nil,
      title: item.title, body: item.body,
      createdAt: "2026-11-04T00:00:00.000Z", readAt: "invalid", route: nil
    )
    #expect(throws: UserNotificationError.invalidResponse) { try badReadDate.toDomain() }

    let missingTitle = Data(#"""
      {"code":"SUCCESS","message":"OK","data":{"items":[
        {"id":"ntf_0123456789abcdef0123456789abcdef","type":"festival.start",
         "festivalId":null,"title":null,"body":"본문",
         "createdAt":"2026-11-04T00:00:00.000Z","readAt":null,"route":null}
      ],"nextCursor":null}}
      """#.utf8)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(UserNotificationListResponseDTO.self, from: missingTitle)
    }
  }

  @Test func useCaseForwardsRepositoryAndLiveDependenciesResolve() async throws {
    let expected = UserNotificationPage(items: [], nextCursor: "next")
    let useCase = withDependencies {
      $0.userNotificationRepository = MockUserNotificationRepository(notifications: { _ in expected })
    } operation: { UserNotificationUseCaseImpl() }

    #expect(try await useCase.notifications(before: nil) == expected)
    #expect(UserNotificationRepositoryDependency.liveValue is UserNotificationRepositoryImpl)
    #expect(UserNotificationUseCaseDependency.liveValue is UserNotificationUseCaseImpl)
  }
}
