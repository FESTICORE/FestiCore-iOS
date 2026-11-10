//
//  AccountSettingsFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import Foundation
import Testing
@testable import Profile

@MainActor
struct AccountSettingsFeatureTests {
  @Test func logoutAndWithdrawRequireConfirmation() async {
    let store = TestStore(initialState: AccountSettingsFeature.State(profile: profile(nickname: "로이"))) {
      AccountSettingsFeature()
    }

    await store.send(.view(.logoutTapped)) {
      $0.destination = .alert(.logout())
      $0.confirmation = .logout
    }
    // 같은 팝업을 다시 띄우지 않는다.
    await store.send(.view(.logoutTapped))
    await store.send(.destination(.presented(.alert(.cancelTapped)))) {
      $0.destination = nil
      $0.confirmation = nil
    }
    await store.send(.view(.withdrawTapped)) {
      $0.destination = .alert(.withdraw())
      $0.confirmation = .withdraw
    }
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
      $0.confirmation = nil
    }
    await store.receive(\.delegate.withdrawRequested)
    await store.send(.view(.logoutTapped)) {
      $0.destination = .alert(.logout())
      $0.confirmation = .logout
    }
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
      $0.confirmation = nil
    }
    await store.receive(\.delegate.logoutRequested)
  }

  @Test func busyAccountDoesNotOpenConfirmationOrNickname() async {
    let store = TestStore(
      initialState: AccountSettingsFeature.State(profile: profile(nickname: "로이"), isLoading: true)
    ) {
      AccountSettingsFeature()
    }

    await store.send(.view(.logoutTapped))
    await store.send(.view(.nicknameTapped))
  }

  @Test func savedNicknameUpdatesScreenAndNotifiesApp() async {
    let updated = profile(nickname: "새이름").user
    let store = TestStore(initialState: AccountSettingsFeature.State(profile: profile(nickname: "로이"))) {
      AccountSettingsFeature()
    } withDependencies: {
      $0.authUseCase = NicknameAuthUseCase(result: .success(updated))
    }

    await store.send(.view(.nicknameTapped)) {
      $0.destination = .nickname(.init(nickname: "로이"))
    }
    await store.send(.destination(.presented(.nickname(.view(.nicknameChanged(" 새이름 ")))))) {
      $0.destination = .nickname(.init(nickname: " 새이름 "))
    }
    await store.send(.destination(.presented(.nickname(.view(.saveTapped))))) {
      $0.destination = .nickname({
        var state = NicknameEditFeature.State(nickname: " 새이름 ")
        state.isSaving = true
        return state
      }())
    }
    await store.receive(\.destination.presented.nickname.async.save)
    await store.receive(\.destination.presented.nickname.inner.saved) {
      $0.destination = .nickname(.init(nickname: " 새이름 "))
    }
    await store.receive(\.destination.presented.nickname.delegate.saved) {
      $0.destination = nil
      $0.profile = self.profile(nickname: "새이름")
    }
    await store.receive(\.delegate.nicknameUpdated)
  }

  @Test func nicknameRulesFollowSignUp() async {
    let store = TestStore(initialState: NicknameEditFeature.State(nickname: "")) {
      NicknameEditFeature()
    } withDependencies: {
      $0.authUseCase = NicknameAuthUseCase(result: .failure(.invalidResponse))
    }

    await store.send(.view(.saveTapped)) { $0.errorMessage = "닉네임은 1~12자로 입력해 주세요." }
    // 앞뒤 공백은 길이에 세지 않는다.
    await store.send(.view(.nicknameChanged("  열두글자딱맞는닉네임이에 "))) {
      $0.nickname = "  열두글자딱맞는닉네임이에 "
      $0.errorMessage = nil
    }
    await store.send(.view(.nicknameChanged("열세글자가넘는아주긴닉네임"))) {
      $0.nickname = "열세글자가넘는아주긴닉네"
    }
    // 앞 공백을 뺀 13자도 12자로 잘린다.
    await store.send(.view(.nicknameChanged("  열세글자가넘는아주긴닉네임")))
    #expect(store.state.nickname == "열세글자가넘는아주긴닉네")
    await store.send(.view(.saveTapped)) { $0.isSaving = true }
    await store.receive(\.async.save)
    await store.receive(\.inner.failed) {
      $0.isSaving = false
      $0.errorMessage = "닉네임을 바꾸지 못했어요. 다시 시도해 주세요."
    }
  }

  private func profile(nickname: String) -> AuthProfile {
    AuthProfile(
      user: AuthUser(
        id: "user-a", provider: "apple", email: nil, nickname: nickname, nicknameConfirmed: true,
        termsAcceptedAt: "2026-10-01", termsVersion: "2026-10", pushOptIn: false, profileImageURL: nil
      ),
      currentTermsVersion: "2026-10"
    )
  }
}

private struct NicknameAuthUseCase: AuthUseCaseInterface {
  let result: Result<AuthUser, AuthDomainError>

  func signIn(with _: AuthCredential) async throws -> AuthLoginResult { throw AuthDomainError.invalidResponse }
  func fetchProfile() async throws -> AuthProfile { throw AuthDomainError.invalidResponse }
  func updateProfile(nickname _: String, termsVersion _: String, pushOptIn _: Bool) async throws -> AuthUser {
    throw AuthDomainError.invalidResponse
  }
  func updateNickname(_: String) async throws -> AuthUser { try result.get() }
  func signOut() async throws {}
  func withdraw() async throws {}

  func commitSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.commitSession 미등록")
    return false
  }

  func discardSession(_ id: UUID) async -> Bool {
    Issue.record("authUseCase.discardSession 미등록")
    return false
  }

  func signOut(ifSession id: UUID) async -> Bool {
    Issue.record("authUseCase.signOut(ifSession:) 미등록")
    return false
  }
}
