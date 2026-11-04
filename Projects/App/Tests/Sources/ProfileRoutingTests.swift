import Foundation
import Testing
import TCAFlow
@testable import FestiCore

@MainActor
struct ProfileRoutingTests {
  @Test("법적 문서는 API 주소를 보존하며 push로 표시한다")
  func legalDocumentIsPushRoute() {
    let url = URL(string: "https://festicore-dev.up.railway.app/api/v1/legal/privacy")!
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.profileState.destination = .legalDocument(.init(
      url: url,
      title: "개인정보 처리방침"
    ))

    #expect(state.profileState.profileRoutes.count == 2)
    #expect(state.profileState.profileRoutes[1].isPush)
    #expect(state.profileState.profileRoutes[1].screen.legalDocument?.url == url)

    state.profileState.destination = nil
    #expect(state.profileState.profileRoutes.count == 1)
  }

  @Test("공지와 팩 상세는 각각 push 경로로 표시한다")
  func noticeAndPackDetailArePushRoutes() {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.profileState.destination = .noticeList(.init())
    #expect(state.profileState.profileRoutes[1].isPush)
    #expect(state.profileState.profileRoutes[1].screen.is(\.noticeList))

    state.profileState.destination = .packDetail(.init(
      festivalID: "festival",
      title: "축제 팩"
    ))
    #expect(state.profileState.profileRoutes[1].isPush)
    #expect(state.profileState.profileRoutes[1].screen.packDetail?.festivalID == "festival")
  }
}
