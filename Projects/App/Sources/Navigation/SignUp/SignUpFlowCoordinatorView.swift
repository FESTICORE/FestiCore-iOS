import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

struct SignUpFlowCoordinatorView: View {
  @Bindable var store: StoreOf<SignUpFlowCoordinator>

  var body: some View {
    TCAFlowRouter(store.scope(
      \.routes,
      action: \.router
    )) { screen in
      switch screen.case {
      case let .signUp(signUpStore):
        SignUpView(store: signUpStore)
      case let .legalDocument(webStore):
        WebView(store: webStore)
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      }
    }
  }
}
