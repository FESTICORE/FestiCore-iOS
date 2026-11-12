import ComposableArchitecture
import FeatureAssembly
import Foundation
import Testing
import TCAFlow
@testable import FestiCore

@MainActor
struct ProfileRoutingTests {
  @Test("마이 설정 버튼은 설정 홈을 push하고 설정 홈의 법적 문서는 그 위에 push한다")
  func coordinatorReducesSettingsRoutes() async {
    guard let baseURL = LegalDocumentURL.baseURL else {
      Issue.record("앱 Info.plist에 약관 기준 주소가 없어요")
      return
    }
    let store = TestStore(initialState: ProfileCoordinator.State()) {
      ProfileCoordinator()
    }

    await store.send(.router(.routeAction(
      id: 0,
      action: .profile(.view(.settingsTapped))
    )))
    await store.receive(\.profile.view) {
      $0.destination = .settings(.init())
    }
    #expect(store.state.profileRoutes.count == 2)
    #expect(store.state.profileRoutes[1].isPush)
    #expect(store.state.profileRoutes[1].screen.is(\.settings))

    await store.send(.router(.routeAction(
      id: 1,
      action: .settings(.view(.privacyTapped))
    )))
    await store.receive(\.profile.destination.presented.settings.view) {
      $0.destination = .settings(settings(.legalDocument(.init(
        url: baseURL.appending(path: "privacy"),
        title: "개인정보 처리방침"
      ))))
    }
    #expect(store.state.profileRoutes.count == 3)
    #expect(store.state.profileRoutes[2].screen.legalDocument?.url == baseURL.appending(path: "privacy"))

    // 법적 문서에서 뒤로 밀면 설정 홈으로 돌아온다.
    await store.send(.router(.updateRoutes(Array(store.state.profileRoutes.prefix(2)))))
    await store.receive(\.profile.destination.presented.settings.destination.dismiss) {
      $0.destination = .settings(.init())
    }
    #expect(store.state.profileRoutes.count == 2)

    // Figma S13-0 '정보 출처' 줄은 수집 출처 공개 문서를 같은 법적 문서 화면으로 연다.
    await store.send(.router(.routeAction(
      id: 1,
      action: .settings(.view(.sourcesTapped))
    )))
    await store.receive(\.profile.destination.presented.settings.view) {
      $0.destination = .settings(settings(.legalDocument(.init(
        url: baseURL.appending(path: "sources"),
        title: "정보 출처"
      ))))
    }
    #expect(store.state.profileRoutes[2].screen.legalDocument?.url == baseURL.appending(path: "sources"))
    await store.send(.router(.updateRoutes(Array(store.state.profileRoutes.prefix(2)))))
    await store.receive(\.profile.destination.presented.settings.destination.dismiss) {
      $0.destination = .settings(.init())
    }

    // 설정 홈에서 뒤로 밀면 마이로 돌아온다.
    await store.send(.router(.updateRoutes(Array(store.state.profileRoutes.prefix(1)))))
    await store.receive(\.profile.destination.dismiss) {
      $0.destination = nil
    }
    #expect(store.state.profileRoutes.count == 1)
    await store.finish()
  }

  @Test("설정 홈의 뒤로 가기 버튼은 마이로 돌아온다")
  func settingsBackButtonReturnsToProfile() async {
    var state = ProfileCoordinator.State()
    state.destination = .settings(.init())
    let store = TestStore(initialState: state) {
      ProfileCoordinator()
    }

    await store.send(.router(.routeAction(
      id: 1,
      action: .settings(.view(.backTapped))
    )))
    await store.receive(\.profile.destination.presented.settings.view)
    await store.receive(\.profile.destination.presented.settings.delegate.backRequested) {
      $0.destination = nil
    }
    await store.finish()
  }

  @Test("약관 행은 앱 설정의 약관 기준 주소로 앱 안 문서를 연다")
  func legalRowsOpenInAppAndBackReturnsToSettings() async {
    guard let base = LegalDocumentURL.baseURL else {
      Issue.record("앱 Info.plist에 약관 기준 주소가 없어요")
      return
    }
    let store = TestStore(initialState: SettingsHomeFeature.State()) {
      SettingsHomeFeature()
    }

    await store.send(.view(.termsTapped)) {
      $0.destination = .legalDocument(.init(
        url: base.appending(path: "terms"),
        title: "이용약관"
      ))
    }
    await store.send(.destination(.presented(.legalDocument(.delegate(.backToRoot))))) {
      $0.destination = nil
    }
    await store.send(.view(.privacyTapped)) {
      $0.destination = .legalDocument(.init(
        url: base.appending(path: "privacy"),
        title: "개인정보 처리방침"
      ))
    }
    await store.send(.destination(.presented(.legalDocument(.delegate(.backToRoot))))) {
      $0.destination = nil
    }
  }

  @Test("설정 홈 아래 화면의 뒤로 가기도 코디네이터 안에서 처리한다")
  func coordinatorReducesChildBackAction() async {
    var state = ProfileCoordinator.State()
    state.destination = .settings(settings(.noticeList(.init())))
    let store = TestStore(initialState: state) {
      ProfileCoordinator()
    }

    await store.send(.router(.routeAction(
      id: 2,
      action: .noticeList(.delegate(.backRequested))
    )))
    await store.receive(\.profile.destination.presented.settings.destination.presented.noticeList.delegate) {
      $0.destination = .settings(.init())
    }
    await store.finish()
  }

  @Test("마이 로그인 요청은 자식 코디네이터에서 홈으로 한 번 전달한다")
  func profileLoginDelegateReachesHome() async {
    let store = TestStore(initialState: MainTabCoordinator.State(selectedTab: .my)) {
      MainTabCoordinator()
    }

    await store.send(.profileCoordinator(.router(.routeAction(
      id: 0,
      action: .profile(.view(.loginTapped))
    ))))
    await store.receive(\.profileCoordinator.profile.view)
    await store.receive(\.profileCoordinator.profile.delegate.loginRequested)
    await store.receive {
      guard case .auth(.view(.loginRequested(.none))) = $0 else { return false }
      return true
    } assert: {
      $0.authFlow.generation = 1
      $0.authFlow.presentation = .login
    }
    await store.finish()
  }

  @Test("받은 팩이 없을 때 '페스티벌 둘러보기'는 라이브 탭의 페스티벌 목록(S00)으로 간다")
  func browseFestivalsOpensFestivalList() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.festivalState.routes.push(.liveBoard(.init(selectedFestivalID: "fst_a")))
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }

    await store.send(.profileCoordinator(.router(.routeAction(
      id: 0,
      action: .profile(.view(.browseFestivalsTapped))
    ))))
    await store.receive(\.profileCoordinator.profile.view)
    await store.receive(\.profileCoordinator.profile.delegate.festivalListRequested) {
      $0.previousTab = .my
      $0.selectedTab = .live
    }
    await store.receive(\.festival.showFestivalList) {
      $0.festivalState.routes.removeAll { !$0.screen.is(\.festivalList) }
    }
    #expect(store.state.festivalState.routes.count == 1)
    await store.finish()
  }

  @Test("계정 로그아웃 확인은 설정 홈과 마이 코디네이터를 거쳐 기존 앱 로그아웃 요청으로 전달한다")
  func accountLogoutConfirmationReachesHome() async {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.profileState.hasSession = true
    var settingsState = SettingsHomeFeature.State(hasSession: true)
    settingsState.destination = .account(.init(profile: nil))
    state.profileState.destination = .settings(settingsState)
    let store = TestStore(initialState: state) {
      MainTabCoordinator()
    }
    store.exhaustivity = .off

    await store.send(.profileCoordinator(.router(.routeAction(
      id: 2,
      action: .account(.view(.logoutTapped))
    ))))
    await store.receive {
      guard case .profileCoordinator(.profile(.destination(.presented(.settings(.destination(.presented(
        .account(.view(.logoutTapped))
      ))))))) = $0 else {
        return false
      }
      return true
    }
    #expect(store.state.profileState.destination?.settings?.destination?.account?.confirmation == .logout)

    await store.send(.profileCoordinator(.router(.routeAction(
      id: 2,
      action: .account(.destination(.presented(.alert(.confirmTapped))))
    ))))
    await store.receive {
      guard case .account(.view(.signOutRequested)) = $0 else { return false }
      return true
    }
  }

  @Test("법적 문서는 API 주소를 보존하며 설정 홈 위에 push로 표시한다")
  func legalDocumentIsPushRoute() {
    let url = URL(string: "https://festicore-dev.up.railway.app/api/v1/legal/privacy")!
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.profileState.destination = .settings(settings(.legalDocument(.init(
      url: url,
      title: "개인정보 처리방침"
    ))))

    #expect(state.profileState.profileRoutes.count == 3)
    #expect(state.profileState.profileRoutes[1].screen.is(\.settings))
    #expect(state.profileState.profileRoutes[2].isPush)
    #expect(state.profileState.profileRoutes[2].screen.legalDocument?.url == url)

    state.profileState.destination = nil
    #expect(state.profileState.profileRoutes.count == 1)
  }

  @Test("공지는 설정 홈 위에, 팩 상세는 마이 위에 push 경로로 표시한다")
  func noticeAndPackDetailArePushRoutes() {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.profileState.destination = .settings(settings(.noticeList(.init())))
    #expect(state.profileState.profileRoutes[2].isPush)
    #expect(state.profileState.profileRoutes[2].screen.is(\.noticeList))

    state.profileState.destination = .packDetail(.init(
      festivalID: "festival",
      title: "축제 팩"
    ))
    #expect(state.profileState.profileRoutes.count == 2)
    #expect(state.profileState.profileRoutes[1].isPush)
    #expect(state.profileState.profileRoutes[1].screen.packDetail?.festivalID == "festival")
  }

  @Test("공지 상세는 마이 코디네이터의 네 번째 push 경로이며 뒤로 가면 목록으로 돌아온다")
  func noticeDetailSwipePopReturnsToList() async {
    var state = ProfileCoordinator.State()
    var noticeList = NoticeListFeature.State()
    noticeList.destination = .detail(.init(
      id: "notice-1",
      title: "공지"
    ))
    state.destination = .settings(settings(.noticeList(noticeList)))
    #expect(state.profileRoutes.count == 4)
    #expect(state.profileRoutes[3].isPush)
    #expect(state.profileRoutes[3].screen.noticeDetail?.id == "notice-1")

    let store = TestStore(initialState: state) {
      ProfileCoordinator()
    }
    store.exhaustivity = .off
    await store.send(.router(.updateRoutes(Array(store.state.profileRoutes.prefix(3)))))
    await store.receive {
      guard case .profile(.destination(.presented(.settings(.destination(.presented(
        .noticeList(.destination(.dismiss))
      )))))) = $0 else {
        return false
      }
      return true
    }
    #expect(store.state.destination?.settings?.destination?.noticeList?.destination == nil)
    #expect(store.state.profileRoutes.count == 3)
  }

  @Test("마이 설정 홈은 탭바를 보이고 그 아래 계정·설정·정보 화면에서 탭바를 숨기며 복귀하면 표시한다")
  func profileInformationRoutesHideTabBarUntilDismissed() {
    var state = MainTabCoordinator.State(selectedTab: .my)
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    // Figma S13-0: 설정 홈에는 마이 탭이 선택된 탭바가 있다.
    state.profileState.destination = .settings(.init())
    #expect(state.profileState.profileRoutes.last?.screen.is(\.settings) == true)
    #expect(!state.shouldHideTabBar)
    #expect(state.shouldReserveTabBarSpace)

    let baseURL = URL(string: "https://festicore-dev.up.railway.app/api/v1/legal")!
    let children: [SettingsHomeFeature.Destination.State] = [
      .account(.init(profile: nil)),
      .notifications(.init()),
      .lockScreen(.init()),
      .appearance(.init()),
      .noticeList(.init()),
      .legalDocument(.init(
        url: baseURL.appending(path: "terms"),
        title: "이용약관"
      )),
      .legalDocument(.init(
        url: baseURL.appending(path: "privacy"),
        title: "개인정보 처리방침"
      )),
    ]
    for child in children {
      state.profileState.destination = .settings(settings(child))
      #expect(state.profileState.profileRoutes.count == 3)
      #expect(state.profileState.profileRoutes.last?.screen.is(\.settings) == false)
      #expect(state.shouldHideTabBar)
      #expect(!state.shouldReserveTabBarSpace)
    }

    state.profileState.destination = .packDetail(.init(
      festivalID: "festival",
      title: "축제 팩"
    ))
    #expect(state.profileState.profileRoutes.last?.screen.is(\.packDetail) == true)
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

  private func settings(_ destination: SettingsHomeFeature.Destination.State) -> SettingsHomeFeature.State {
    var settings = SettingsHomeFeature.State()
    settings.destination = destination
    return settings
  }
}
