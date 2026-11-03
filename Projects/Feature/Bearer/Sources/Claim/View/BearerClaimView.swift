//
//  BearerClaimView.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// Figma S13 F~I 기수 인증 코드(입력 전·입력 중·틀림·잠김)
@ViewAction(for: BearerClaimFeature.self)
public struct BearerClaimView: View {
  @Bindable public var store: StoreOf<BearerClaimFeature>
  @FocusState private var isCodeFocused: Bool

  public init(store: StoreOf<BearerClaimFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: "기수 인증")
        .onBack { send(.backTapped) }
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          header
          VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM12) {
            codeInput
            notices
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollDismissesKeyboard(.never)
      FCPrimaryButton(store.isSubmitting ? "확인하는 중" : "확인", isEnabled: store.canSubmit) {
        send(.submitTapped)
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .padding(.top, FestiCoreSpacing.paddingP12)
      .padding(.bottom, FestiCoreSpacing.paddingP8)
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .onAppear { isCodeFocused = !store.isLocked }
  }
}

extension BearerClaimView {
  private var header: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM8) {
      Text("운영팀에게 받은\n코드 6자리를 입력해 주세요")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text("영문과 숫자로 된 코드예요. 페스티벌마다 달라요.")
        .festiCoreFont(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var codeInput: some View {
    ZStack {
      BearerCodeBoxes(
        code: store.code,
        length: BearerClaimFeature.codeLength,
        isFocused: isCodeFocused,
        isError: isInvalid,
        isDisabled: store.isLocked
      )
      TextField(
        "",
        text: Binding(
          get: { store.code },
          set: { send(.codeChanged($0)) }
        )
      )
      .textInputAutocapitalization(.characters)
      .autocorrectionDisabled()
      .keyboardType(.asciiCapable)
      .textContentType(.oneTimeCode)
      .focused($isCodeFocused)
      .foregroundStyle(.clear)
      .tint(.clear)
      .disabled(store.isLocked || store.isSubmitting)
      .accessibilityLabel("기수 인증 코드")
      .onSubmit { send(.submitTapped) }
    }
    .contentShape(Rectangle())
    .onTapGesture { isCodeFocused = !store.isLocked }
  }

  @ViewBuilder
  private var notices: some View {
    switch store.failure {
    case .invalid(let remaining)?:
      BearerNoticeLine(text: remaining > 0 ? "코드가 맞지 않아요 · \(remaining)번 남았어요" : "코드가 맞지 않아요", isWarning: true)
      BearerNoticeLine(text: "3번 틀리면 10분 동안 입력할 수 없어요.", isWarning: false)
    case .locked?:
      BearerNoticeLine(text: "3번 틀려서 입력이 잠겼어요", isWarning: true)
      BearerNoticeLine(text: "\(lockRemainingText) 뒤에 다시 입력할 수 있어요.", isWarning: false)
    case .message(let message)?:
      BearerNoticeLine(text: message, isWarning: true)
    case nil:
      BearerNoticeLine(text: "코드는 운영팀이 기수에게 직접 알려 드려요.", isWarning: false)
    }
  }

  private var isInvalid: Bool {
    if case .invalid = store.failure { return true }
    return false
  }

  private var lockRemainingText: String {
    let seconds = store.lockRemainingSeconds
    return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
  }
}

#Preview {
  BearerClaimView(store: .init(initialState: BearerClaimFeature.State(festivalID: "fst_preview")) {
    BearerClaimFeature()
  })
}
