//
//  SignUpView.swift
//  Auth
//
//  Created by FestiCore on 11/2/26.
//

import AuthDomainInterface
import AuthInterface
import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI
import UIKit

/// Figma S14-2 가입 정보(닉네임·약관 동의)
@ViewAction(for: SignUpFeature.self)
public struct SignUpView: View {
  @Bindable public var store: StoreOf<SignUpFeature>
  /// 화면 아래 끝의 전역 y. 키보드와 겹치는 높이를 구할 때만 쓰는 배치 값이다.
  @State private var contentBottom: CGFloat = .zero

  public init(store: StoreOf<SignUpFeature>) {
    self.store = store
  }

  public var body: some View {
    content()
      .toolbar(
        .hidden,
        for: .navigationBar
      )
  }
}

private extension SignUpView {
  @ViewBuilder
  func content() -> some View {
    VStack(spacing: .zero) {
      FCTopBar(.back)
        .onBack { send(.closeTapped) }
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          Text("반가워요!\n어떻게 불러 드릴까요?")
            .festiCoreFont(.baseTitle2Bold)
            .festiCoreLineBox(.baseTitle2Bold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .frame(maxWidth: .infinity, alignment: .leading)
          FCTextField(
            text: Binding(
              get: { store.nickname },
              set: { send(.nicknameChanged($0)) }
            ),
            placeholder: "닉네임"
          )
          .label("닉네임")
          .counter(AuthNicknameRule.counterText(store.nickname))
          .helper("크루원과 깃발에 보이는 이름이에요. 나중에 마이에서 바꿀 수 있어요.")
          consentBox()
          if let message = store.message {
            Text(message)
              .festiCoreFont(.baseCaption1Regular)
              .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollDismissesKeyboard(.interactively)
      FCPrimaryButton(
        "다음",
        isEnabled: store.canSubmit
      ) {
        send(.submitTapped)
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .padding(.top, FestiCoreSpacing.paddingP12)
      .padding(.bottom, FestiCoreSpacing.paddingP8)
    }
    .padding(
      .bottom,
      store.keyboardInset
    )
    .onGeometryChange(for: CGFloat.self) { proxy in
      return proxy.frame(in: .global).maxY
    } action: { maxY in
      contentBottom = maxY
    }
    // 전체 화면에서는 SwiftUI 키보드 회피가, 시트에서는 회피가 꺼져 있어 화면마다 달라진다.
    // 회피를 끄고 화면 아래 끝과 키보드가 겹치는 높이만 여백으로 둬 두 번 밀리지 않게 한다.
    .ignoresSafeArea(
      .keyboard,
      edges: .bottom
    )
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
      guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
      send(.keyboardFrameChanged(
        minY: frame.minY,
        contentBottom: contentBottom
      ))
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
      send(.keyboardHidden)
    }
    .onDisappear {
      send(.keyboardHidden)
    }
  }

  @ViewBuilder
  func consentBox() -> some View {
    VStack(spacing: .zero) {
      FCConsentAll(isChecked: store.isAllConsented) {
        send(.allConsentToggled)
      }
      FestiCoreSemanticColor.lineNormal.color
        .frame(height: 1)
      VStack(spacing: .zero) {
        FCConsentRow(LegalDocument.terms.title, isChecked: store.acceptedServiceTerms) {
          send(.serviceTermsChanged(!store.acceptedServiceTerms))
        }
        .tag("필수")
        .onDetail(legalLink(.terms))
        FCConsentRow(LegalDocument.privacy.title, isChecked: store.acceptedPrivacyTerms) {
          send(.privacyTermsChanged(!store.acceptedPrivacyTerms))
        }
        .tag("필수")
        .onDetail(legalLink(.privacy))
      }
      .padding(.vertical, FestiCoreSpacing.paddingP8)
    }
    .overlay {
      RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        .strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: 1)
    }
  }

  /// 약관 상세 링크. 기준 주소가 없으면 화살표를 숨긴다.
  func legalLink(_ document: LegalDocument) -> (() -> Void)? {
    guard store.canOpenLegal else { return nil }
    return { send(.legalDocumentTapped(document)) }
  }
}

#Preview {
  SignUpView(store: Store(initialState: SignUpFeature.State()) { SignUpFeature() })
}
