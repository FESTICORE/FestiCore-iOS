//
//  SignUpView.swift
//  Login
//
//  Created by FestiCore on 11/2/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import LoginInterface
import SwiftUI
import UIKit
import Web

/// Figma S14-2 가입 정보(닉네임·약관 동의)
@ViewAction(for: SignUpFeature.self)
public struct SignUpView: View {
  @Bindable public var store: StoreOf<SignUpFeature>
  @State private var keyboardInset: CGFloat = 0

  public init(store: StoreOf<SignUpFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back)
        .onBack { send(.closeTapped) }
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          Text("반가워요!\n어떻게 불러 드릴까요?")
            .festiCoreFont(.baseTitle2Bold)
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
          consentBox
          if let message = store.message {
            Text(message)
              .festiCoreFont(.baseCaption1Regular)
              .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollDismissesKeyboard(.interactively)
      FCPrimaryButton("시작하기", isEnabled: store.canSubmit) {
        send(.submitTapped)
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .padding(.top, FestiCoreSpacing.paddingP12)
      .padding(.bottom, FestiCoreSpacing.paddingP8)
    }
    .padding(.bottom, keyboardInset)
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
      guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
      keyboardInset = max(0, UIScreen.main.bounds.height - frame.minY)
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
      keyboardInset = 0
    }
    .fullScreenCover(item: $store.scope(state: \.legalDocument, action: \.scope.legalDocument)) { webStore in
      WebView(store: webStore)
    }
  }
}

private extension SignUpView {
  var consentBox: some View {
    VStack(spacing: .zero) {
      FCConsentAll(isChecked: store.isAllConsented) {
        send(.allConsentToggled)
      }
      FestiCoreSemanticColor.lineNormal.color
        .frame(height: 1)
      VStack(spacing: .zero) {
        FCConsentRow("서비스 이용약관", isChecked: store.acceptedServiceTerms) {
          send(.serviceTermsChanged(!store.acceptedServiceTerms))
        }
        .tag("필수")
        .onDetail(legalLink(.terms))
        FCConsentRow("개인정보 수집 · 이용", isChecked: store.acceptedPrivacyTerms) {
          send(.privacyTermsChanged(!store.acceptedPrivacyTerms))
        }
        .tag("필수")
        .onDetail(legalLink(.privacy))
        FCConsentRow("알림 받기", isChecked: store.pushOptIn) {
          send(.pushOptInChanged(!store.pushOptIn))
        }
        .tag("선택")
        .sub("공연 10분 전 · 팔로우한 깃발 · 크루 소식")
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
    guard store.legalBaseURL != nil else { return nil }
    return { send(.legalDocumentTapped(document)) }
  }
}

#Preview {
  SignUpView(store: Store(initialState: SignUpFeature.State()) { SignUpFeature() })
}
