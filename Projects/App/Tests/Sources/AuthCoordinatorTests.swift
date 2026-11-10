import ComposableArchitecture
import FeatureAssembly
import Foundation
import TCAFlow
import Testing
@testable import FestiCore

struct AuthCoordinatorTests {
  @Test @MainActor func legalWebPushAndBackKeepSignUpDraft() async {
    var signUp = SignUpFeature.State()
    signUp.nickname = "테스터"
    signUp.acceptedPrivacyTerms = true
    var state = AuthCoordinator.State()
    state.signUpFlow = AuthCoordinator.SignUpFlow(signUp: signUp)
    let store = TestStore(initialState: state) {
      AuthCoordinator()
    }
    guard let url = signUp.legalURL(for: .privacy) else {
      Issue.record("개인정보 약관 주소를 만들지 못했어요")
      return
    }

    await store.send(.signUp(.router(.routeAction(
      id: 0,
      action: .signUp(.view(.legalDocumentTapped(.privacy)))
    ))))
    await store.receive { action in
      guard case let .signUp(.router(.routeAction(
        id: 0,
        action: .signUp(.delegate(.legalDocumentRequested(
          requestedURL,
          title
        )))
      ))) = action else { return false }
      return requestedURL == url && title == "개인정보 수집 · 이용"
    } assert: {
      $0.signUpFlow.routes.push(.legalDocument(.init(
        url: url,
        title: "개인정보 수집 · 이용"
      )))
    }
    #expect(store.state.signUpFlow.routes.count == 2)

    await store.send(.signUp(.router(.routeAction(
      id: 1,
      action: .legalDocument(.view(.closeTapped))
    ))))
    await store.receive { action in
      guard case .signUp(.router(.routeAction(
        id: 1,
        action: .legalDocument(.delegate(.backToRoot))
      ))) = action else { return false }
      return true
    } assert: {
      $0.signUpFlow.routes.goBack()
    }
    #expect(store.state.signUp.nickname == "테스터")
    #expect(store.state.signUp.acceptedPrivacyTerms)
  }

  @Test @MainActor func sheetCloseResetsWebRouteButKeepsDraft() async {
    var state = AuthCoordinator.State()
    state.signUp.nickname = "작성 중"
    guard let url = state.signUp.legalURL(for: .terms) else {
      Issue.record("서비스 약관 주소를 만들지 못했어요")
      return
    }
    state.signUpFlow.routes.push(.legalDocument(.init(
      url: url,
      title: "서비스 이용약관"
    )))
    let store = TestStore(initialState: state) { AuthCoordinator() }
    await store.send(.signUp(.view(.sheetClosed))) {
      $0.signUpFlow.resetNavigation()
    }
    await store.receive { action in
      guard case .signUp(.router(.routeAction(
        id: 0,
        action: .signUp(.view(.sheetClosed))
      ))) = action else { return false }
      return true
    }
    #expect(store.state.signUpFlow.routes.count == 1)
    #expect(store.state.signUp.nickname == "작성 중")
  }
}
