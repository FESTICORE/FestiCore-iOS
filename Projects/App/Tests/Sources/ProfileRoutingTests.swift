import ComposableArchitecture
import Foundation
import Testing
import TCAFlow
@testable import FestiCore

@MainActor
struct ProfileRoutingTests {
  @Test("마이 코디네이터가 라우터 입력을 직접 처리해 법적 문서를 연다")
  func coordinatorReducesProfileRoute() async {
    let baseURL = URL(string: "https://festicore-dev.up.railway.app/api/v1/legal")!
    let store = TestStore(initialState: ProfileCoordinator.State()) {
      ProfileCoordinator(legalBaseURL: baseURL)
    }

    await store.send(.router(.routeAction(
      id: 0,
      action: .profile(.view(.privacyTapped))
    )))
    await store.receive(\.profile.view) {
      $0.destination = .legalDocument(.init(
        url: baseURL.appending(path: "privacy"),
        title: "개인정보 처리방침"
      ))
    }
    #expect(store.state.profileRoutes[1].isPush)

    await store.send(.router(.updateRoutes([
      .root(
        .profile(store.state),
        embedInNavigationView: true
      )
    ])))
    await store.receive(\.profile.destination.dismiss) {
      $0.destination = nil
    }
    #expect(store.state.profileRoutes.count == 1)
    await store.finish()
  }

  @Test("마이 상세 화면의 뒤로 가기도 코디네이터 안에서 처리한다")
  func coordinatorReducesChildBackAction() async {
    var state = ProfileCoordinator.State()
    state.destination = .noticeList(.init())
    let store = TestStore(initialState: state) {
      ProfileCoordinator(legalBaseURL: nil)
    }

    await store.send(.router(.routeAction(
      id: 1,
      action: .noticeList(.delegate(.backRequested))
    )))
    await store.receive(\.profile.destination.presented.noticeList.delegate) {
      $0.destination = nil
    }
    await store.finish()
  }

  @Test("마이 로그인 요청은 자식 코디네이터에서 홈으로 한 번 전달한다")
  func profileLoginDelegateReachesHome() async {
    let store = TestStore(initialState: MainTabCoordinator.State(selectedTab: .my)) {
      MainTabCoordinator(legalBaseURL: nil)
    }

    await store.send(.profileCoordinator(.router(.routeAction(
      id: 0,
      action: .profile(.view(.accountTapped))
    ))))
    await store.receive(\.profileCoordinator.profile.view)
    await store.receive(\.profileCoordinator.profile.delegate.loginRequested)
    await store.receive {
      guard case .delegate(.myLoginRequested) = $0 else { return false }
      return true
    }
    await store.finish()
  }

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
