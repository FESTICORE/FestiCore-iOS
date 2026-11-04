import ComposableArchitecture
import FeatureAssembly
import Foundation
import TCAFlow
import Testing
@testable import FestiCore

struct SignUpFlowCoordinatorTests {
  @Test @MainActor func legalWebPushAndBackKeepSignUpDraft() async {
    guard let baseURL = AppCoordinatorView.legalBaseURL(host: "festicore-dev.up.railway.app") else {
      Issue.record("Stage 약관 기준 주소를 만들지 못했어요")
      return
    }
    var signUp = SignUpFeature.State(legalBaseURL: baseURL)
    signUp.nickname = "테스터"
    signUp.acceptedPrivacyTerms = true
    let store = TestStore(initialState: SignUpFlowCoordinator.State(signUp: signUp)) {
      SignUpFlowCoordinator()
    }
    guard let url = signUp.legalURL(for: .privacy) else {
      Issue.record("개인정보 약관 주소를 만들지 못했어요")
      return
    }

    await store.send(.router(.routeAction(
      id: 0,
      action: .signUp(.view(.legalDocumentTapped(.privacy)))
    )))
    await store.receive { action in
      guard case let .router(.routeAction(
        id: 0,
        action: .signUp(.delegate(.legalDocumentRequested(
          requestedURL,
          title
        )))
      )) = action else { return false }
      return requestedURL == url && title == "개인정보 수집 · 이용"
    } assert: {
      $0.routes.push(.legalDocument(.init(
        url: url,
        title: "개인정보 수집 · 이용"
      )))
    }
    #expect(store.state.routes.count == 2)

    await store.send(.router(.routeAction(
      id: 1,
      action: .legalDocument(.view(.closeTapped))
    )))
    await store.receive { action in
      guard case .router(.routeAction(
        id: 1,
        action: .legalDocument(.delegate(.backToRoot))
      )) = action else { return false }
      return true
    } assert: {
      $0.routes.goBack()
    }
    #expect(store.state.signUp.nickname == "테스터")
    #expect(store.state.signUp.acceptedPrivacyTerms)
  }

  @Test @MainActor func sheetCloseResetsWebRouteButKeepsDraft() async {
    guard let baseURL = AppCoordinatorView.legalBaseURL(host: "festicore-dev.up.railway.app") else {
      Issue.record("Stage 약관 기준 주소를 만들지 못했어요")
      return
    }
    var state = SignUpFlowCoordinator.State(signUp: .init(legalBaseURL: baseURL))
    state.signUp.nickname = "작성 중"
    guard let url = state.signUp.legalURL(for: .terms) else {
      Issue.record("서비스 약관 주소를 만들지 못했어요")
      return
    }
    state.routes.push(.legalDocument(.init(
      url: url,
      title: "서비스 이용약관"
    )))
    let store = TestStore(initialState: state) { SignUpFlowCoordinator() }
    await store.send(.view(.sheetClosed)) {
      $0.resetNavigation()
    }
    await store.receive { action in
      guard case .router(.routeAction(
        id: 0,
        action: .signUp(.view(.sheetClosed))
      )) = action else { return false }
      return true
    }
    #expect(store.state.routes.count == 1)
    #expect(store.state.signUp.nickname == "작성 중")
  }
}
