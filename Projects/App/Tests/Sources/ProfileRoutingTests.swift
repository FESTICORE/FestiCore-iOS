import ComposableArchitecture
import FeatureAssembly
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

  @Test("계정 로그아웃 확인은 마이 코디네이터에서 기존 앱 로그아웃 요청으로 전달한다")
  func accountLogoutConfirmationReachesHome() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.profileState.hasSession = true
    state.profileState.destination = .account(.init(profile: nil))
    let store = TestStore(initialState: state) {
      MainTabCoordinator(legalBaseURL: nil)
    }
    store.exhaustivity = .off

    await store.send(.profileCoordinator(.router(.routeAction(
      id: 1,
      action: .account(.view(.logoutTapped))
    ))))
    await store.receive {
      guard case .profileCoordinator(.profile(.destination(.presented(.account(.view(.logoutTapped)))))) = $0 else {
        return false
      }
      return true
    }
    #expect(store.state.profileState.destination?.account?.confirmation == .logout)

    await store.send(.profileCoordinator(.router(.routeAction(
      id: 1,
      action: .account(.destination(.presented(.alert(.confirmTapped))))
    ))))
    await store.receive {
      guard case .delegate(.myLogoutRequested) = $0 else { return false }
      return true
    }
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

  @Test("공지 상세는 마이 코디네이터의 세 번째 push 경로이며 뒤로 가면 목록으로 돌아온다")
  func noticeDetailSwipePopReturnsToList() async {
    var state = ProfileCoordinator.State()
    var noticeList = NoticeListFeature.State()
    noticeList.destination = .detail(.init(
      id: "notice-1",
      title: "공지"
    ))
    state.destination = .noticeList(noticeList)
    #expect(state.profileRoutes.count == 3)
    #expect(state.profileRoutes[2].isPush)
    #expect(state.profileRoutes[2].screen.noticeDetail?.id == "notice-1")

    let store = TestStore(initialState: state) {
      ProfileCoordinator(legalBaseURL: nil)
    }
    store.exhaustivity = .off
    await store.send(.router(.updateRoutes(Array(store.state.profileRoutes.prefix(2)))))
    await store.receive {
      guard case .profile(.destination(.presented(.noticeList(.destination(.dismiss))))) = $0 else {
        return false
      }
      return true
    }
    #expect(store.state.destination?.noticeList?.destination == nil)
    #expect(store.state.profileRoutes.count == 2)
  }

  @Test("마이 설정·정보 화면 다섯 곳에서 탭바를 숨기고 복귀하면 표시한다")
  func profileInformationRoutesHideTabBarUntilDismissed() {
    var state = MainTabCoordinator.State(selectedTab: .my)
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    state.profileState.destination = .notifications(.init())
    #expect(state.profileState.profileRoutes.last?.screen.is(\.notifications) == true)
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)

    state.profileState.destination = .lockScreen(.init())
    #expect(state.profileState.profileRoutes.last?.screen.is(\.lockScreen) == true)
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)

    state.profileState.destination = .noticeList(.init())
    #expect(state.profileState.profileRoutes.last?.screen.is(\.noticeList) == true)
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)

    let baseURL = URL(string: "https://festicore-dev.up.railway.app/api/v1/legal")!
    state.profileState.destination = .legalDocument(.init(
      url: baseURL.appending(path: "terms"),
      title: "이용약관"
    ))
    #expect(state.profileState.profileRoutes.last?.screen.is(\.legalDocument) == true)
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)

    state.profileState.destination = .legalDocument(.init(
      url: baseURL.appending(path: "privacy"),
      title: "개인정보 처리방침"
    ))
    #expect(state.profileState.profileRoutes.last?.screen.is(\.legalDocument) == true)
    #expect(state.shouldHideTabBar)
    #expect(!state.shouldReserveTabBarSpace)

    state.profileState.destination = nil
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)
  }

  @Test("라이브 보드의 메인 탭바는 유지된다")
  func liveBoardKeepsMainTabBar() {
    var state = MainTabCoordinator.State(selectedTab: .live)
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "festival")))

    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)
  }
}
