//
//  AppCoordinator+ScopeAction.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import API
import ComposableArchitecture
import CoreAssembly
import FeatureAssembly
import FestiCoreAnalyticsInterface
import FestivalDomainInterface
import FestiCoreAuthInterface
import FestiCoreDeviceInterface
import FestiCoreStorageInterface
import Foundation
import OSLog

extension AppCoordinator {
  func handleScopeAction(
    state: inout State,
    action: ScopeAction
  ) -> Effect<Action> {
    switch action {
    case .splash(.delegate(.presentHome)):
      return .send(.view(.presentHome))
    case .onboarding(.delegate(.completed)):
      return .run { send in
        do {
          try firstInstallOnboardingStore.markCompleted()
        } catch {
          FestiCoreLogger.error(
            "첫 설치 기록을 저장할 수 없음: \(error.localizedDescription)",
            category: .app)
        }
        await send(.inner(.completeHomeTransition))
      }

    case let .home(.scopeAction(.festival(.delegate(.bookmarkRequested(id))))):
      guard case var .home(home) = state,
            home.authFlow.accountOperationGeneration == nil else { return .none }
      home.authFlow.generation += 1
      home.authFlow.pendingFestivalID = id
      if let userID = home.authFlow.verifiedUserID,
         home.authFlow.profile?.isEligible == true {
        home.authFlow.pendingShouldBeBooked = !festivalLibraryUseCase.bookedFestivalIDs(for: userID).contains(id)
      } else {
        home.authFlow.pendingShouldBeBooked = !isBooked(
          id,
          in: home.tabs.festival
        )
      }
      home.authFlow.pendingOwnerID = home.authFlow.verifiedUserID ?? home.authFlow.lastVerifiedUserID
      home.authFlow.message = nil
      home.authFlow.hasRetriedTermsUpdate = false
      home.authFlow.termsUpdateExhausted = false
      let generation = home.authFlow.generation
      home.authFlow.isLoading = true
      state = .home(home)
      return fetchProfile(generation: generation)

    case let .home(.scopeAction(.signUp(.delegate(.submitRequested(submission))))):
      analyticsUseCase.track(
        .uiAction(
          action: .signUpSubmit,
          screen: .signUp
        )
      )
      guard case var .home(home) = state,
            home.authFlow.presentation == .onboarding,
            let profile = home.authFlow.profile,
            home.authFlow.signUp.acceptedTerms,
            home.authFlow.signUp.consentedVersion == profile.currentTermsVersion,
            !home.authFlow.termsUpdateExhausted,
            !home.authFlow.isLoading else { return .none }
      let nickname = submission.nickname
      guard submission.isNicknameValid else {
        home.authFlow.message = "닉네임은 1~12자로 입력해 주세요."
        state = .home(home)
        return .none
      }
      home.authFlow.isLoading = true
      home.authFlow.message = nil
      let generation = home.authFlow.generation
      let pushOptIn = submission.pushOptIn
      state = .home(home)
      return .run { send in
        do {
          let user = try await authUseCase.updateProfile(
            nickname: nickname,
            termsVersion: profile.currentTermsVersion,
            pushOptIn: pushOptIn
          )
          await send(.inner(.profileUpdated(
            generation: generation,
            .success(user))))
        } catch {
          await send(.inner(.profileUpdated(
            generation: generation,
            .failure(ProfileFailure(error)))))
        }
      }

    case .home(.scopeAction(.login(.view(.signInTapped(.google))))):
      analyticsUseCase.track(
        .uiAction(
          action: .loginGoogle,
          screen: .login
        )
      )
      return .none

    case .home(.scopeAction(.login(.view(.signInTapped(.apple))))):
      analyticsUseCase.track(
        .uiAction(
          action: .loginApple,
          screen: .login
        )
      )
      return .none

    case .home(.scopeAction(.flag(.directory(.sortTapped)))):
      analyticsUseCase.track(
        .uiAction(
          action: .flagSort,
          screen: .festivalFlag
        )
      )
      return .none

    case .home(.scopeAction(.timetable(.view(.searchTapped)))):
      analyticsUseCase.track(
        .uiAction(
          action: .timetableSearch,
          screen: .timetable
        )
      )
      return .none

    case .home(.scopeAction(.timetable(.view(.notifyTapped)))):
      analyticsUseCase.track(
        .uiAction(
          action: .timetableNotify,
          screen: .timetable
        )
      )
      return .none

    case let .home(.scopeAction(.profileCoordinator(.router(.routeAction(
      id: 1,
      action: .packDetail(.view(action))
    ))))):
      return trackPackDetailAction(action)

    case .home(.scopeAction(.profileCoordinator(.router(.routeAction(
      id: 1,
      action: .account(.view(.nicknameTapped))
    ))))):
      return trackUIAction(
        .profileNicknameEdit,
        screen: .profile
      )

    case .home(.scopeAction(.profileCoordinator(.router(.routeAction(
      id: 1,
      action: .account(.destination(.presented(.nickname(.view(.saveTapped)))))
    ))))):
      return trackUIAction(
        .profileNicknameSave,
        screen: .profile
      )

    case .home(.scopeAction(.signUp(.delegate(.closeRequested)))):
      return handleViewAction(
        state: &state,
        action: .dismissFlow)

    case .home(.scopeAction(.login(.delegate(.closeRequested)))):
      return handleViewAction(
        state: &state,
        action: .dismissFlow
      )

    case let .home(.scopeAction(.login(.delegate(.signInRequested(provider))))):
      return handleViewAction(
        state: &state,
        action: .startLogin(provider))

    case let .home(.scopeAction(.login(.delegate(.signedIn(result))))):
      guard case let .home(home) = state else { return .none }
      let accepted = isActiveLoginAttempt(home.authFlow)
      guard let sessionID = result.sessionID else {
        return accepted ? acceptLogin(
          result,
          state: &state) : .none
      }
      guard accepted else {
        // 시트를 닫은 뒤 끝난 로그인은 확정하지 않고 그 임시 세션만 버린다.
        return .run { _ in _ = await authService.discardSession(sessionID) }
      }
      var accepting = home
      accepting.authFlow.pendingCommitSessionID = sessionID
      state = .home(accepting)
      let generation = home.authFlow.generation
      return .run { send in
        let committed = await authService.commitSession(sessionID)
        await send(.inner(.loginCommitted(
          result,
          generation: generation,
          committed: committed)))
      }

    case .home(.delegate(.myLoginRequested)),
         .home(.delegate(.myCrewLoginRequested)),
         .home(.delegate(.myFollowLoginRequested)):
      guard case var .home(home) = state,
            !home.authFlow.isLoading else { return .none }
      home.authFlow.generation += 1
      home.authFlow.pendingFestivalID = nil
      home.authFlow.pendingOwnerID = nil
      home.authFlow.message = nil
      switch action {
      case .home(.delegate(.myCrewLoginRequested)):
        home.authFlow.loginContextOverride = .crew
      case .home(.delegate(.myFollowLoginRequested)):
        home.authFlow.loginContextOverride = .follow
      default:
        home.authFlow.loginContextOverride = nil
      }
      home.authFlow.presentation = .login
      state = .home(home)
      return .none

    case .home(.delegate(.myProfileRefreshRequested)):
      return .send(.view(.retryProfile))

    case .home(.delegate(.dismissAuthFlow)):
      return handleViewAction(
        state: &state,
        action: .dismissFlow
      )

    case .home(.delegate(.retryProfile)):
      return handleViewAction(
        state: &state,
        action: .retryProfile
      )

    case let .home(.delegate(.resolveMigration(shouldRestore))):
      return handleViewAction(
        state: &state,
        action: .resolveMigration(shouldRestore)
      )

    case .home(.delegate(.myLogoutRequested)):
      analyticsUseCase.track(
        .uiAction(
          action: .profileLogout,
          screen: .profile
        )
      )
      return myAccountOperation(
        state: &state,
        operation: .signOut)

    case .home(.delegate(.myWithdrawRequested)):
      analyticsUseCase.track(
        .uiAction(
          action: .profileWithdraw,
          screen: .profile
        )
      )
      return myAccountOperation(
        state: &state,
        operation: .withdraw)

    case let .home(.delegate(.myProfileUpdated(user))):
      // 바꾼 닉네임을 세션의 표시 이름에 바로 반영한다. 같은 계정일 때만 받는다.
      guard case var .home(home) = state,
            let previous = home.authFlow.profile,
            previous.user.id == user.id else { return .none }
      home.authFlow.profile = AuthProfile(
        user: user,
        currentTermsVersion: previous.currentTermsVersion)
      state = .home(home)
      return .none

    default:
      return .none
    }
  }

  private func trackPackDetailAction(
    _ action: PackDetailFeature.View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      analyticsUseCase.track(
        .screenView(
          screen: .packDetail,
          referrer: .profile
        )
      )
    case .tabSelected(.directions):
      return trackUIAction(
        .packDirectionsTab,
        screen: .packDetail
      )
    case .tabSelected(.checklist):
      return trackUIAction(
        .packChecklistTab,
        screen: .packDetail
      )
    case .tabSelected(.manage):
      return trackUIAction(
        .packManageTab,
        screen: .packDetail
      )
    case .linkTapped:
      return trackUIAction(
        .packLinkOpen,
        screen: .packDetail
      )
    case .retryTapped:
      return trackUIAction(
        .packRetry,
        screen: .packDetail
      )
    case .itemToggled:
      return trackUIAction(
        .packChecklistToggle,
        screen: .packDetail
      )
    case .editTapped:
      return trackUIAction(
        .packChecklistEdit,
        screen: .packDetail
      )
    case .editDoneTapped:
      return trackUIAction(
        .packChecklistEditDone,
        screen: .packDetail
      )
    case .itemRemoved:
      return trackUIAction(
        .packChecklistItemRemove,
        screen: .packDetail
      )
    case .addItemTapped:
      return trackUIAction(
        .packChecklistItemAdd,
        screen: .packDetail
      )
    case .updateTapped, .checkUpdateTapped:
      return trackUIAction(
        .packUpdate,
        screen: .packDetail
      )
    case .autoDownloadToggled:
      return trackUIAction(
        .packAutoDownloadToggle,
        screen: .packDetail
      )
    case .deleteTapped:
      return trackUIAction(
        .packDelete,
        screen: .packDetail
      )
    case .backTapped:
      return .none
    }
    return .none
  }

  private func trackUIAction(
    _ action: AnalyticsButton,
    screen: AnalyticsScreen
  ) -> Effect<Action> {
    analyticsUseCase.track(
      .uiAction(
        action: action,
        screen: screen
      )
    )
    return .none
  }

  func myAccountOperation(
    state: inout State,
    operation: MyAccountOperation
  ) -> Effect<Action> {
    guard case var .home(home) = state,
          home.authFlow.hasSession,
          !home.authFlow.isLoading else { return .none }
    home.authFlow.generation += 1
    home.authFlow.accountOperationGeneration = home.authFlow.generation
    home.authFlow.accountOperation = operation
    home.authFlow.isLoading = true
    home.authFlow.message = nil
    let generation = home.authFlow.generation
    state = .home(home)
    return .run { send in
      do {
        await unbindDeviceForAccountOperation()
        try Task.checkCancellation()
        await endLocalLiveActivities()
        try Task.checkCancellation()
        switch operation {
        case .signOut:
          try await authUseCase.signOut()
        case .withdraw:
          try await authUseCase.withdraw()
        }
        await send(.inner(.myAccountFinished(
          generation: generation,
          operation: operation,
          result: .success(()))))
      } catch {
        guard !Task.isCancelled else { return }
        if !(await authService.isLoggedIn) {
          await send(.inner(.sessionExpired))
          return
        }
        // 인증 요청은 실패했지만 계정이 유지되면 해제했던 기기 소유권을 복원한다.
        await linkDeviceForCurrentUser()
        await send(.inner(.myAccountFinished(
          generation: generation,
          operation: operation,
          result: .failure(ProfileFailure(error))
        )))
      }
    }
    .cancellable(
      id: CancelID.accountOperation,
      cancelInFlight: true)
  }

  private func unbindDeviceForAccountOperation() async {
    do {
      try await deviceRegistrationService.unbindCurrentUser()
    } catch {
      // 바인딩은 다음 실행에서 복구한다. 해제 실패로 계정 요청을 막지 않는다.
      Logger(
        subsystem: "io.festiCore.co",
        category: "DeviceRegistration"
      )
        .error("계정 작업 중 기기 바인딩 해제 실패; 다음 실행에서 복구")
    }
  }

  func linkDeviceForCurrentUser() async {
    do {
      try await deviceRegistrationService.linkDeviceToCurrentUser()
    } catch {
      FestiCoreLogger.error(
        "계정 기기 연결 실패",
        category: .app
      )
    }
  }

  func endLocalLiveActivities() async {
    for activity in await festivalLiveActivityUseCase.activities() {
      await festivalLiveActivityUseCase.end(activityID: activity.id)
    }
  }

  func clearAccountData(_ home: inout MainTabCoordinator.State) -> Effect<Action> {
    clearAccountDisplayData(&home)
    return .send(.scope(.home(.scopeAction(.festival(.accountChanged)))))
  }

  /// 비동기 입력 액션 전에 개인 데이터가 화면에 남지 않도록 동기 정리한다.
  func clearAccountDisplayData(_ home: inout MainTabCoordinator.State) {
    home.tabs.festival.clearAccountData()
    home.tabs.flag.clearAccountData()
    home.tabs.timetableFeature.mySetIDs = []
    home.tabs.timetableFeature.scheduleSync = .idle
    home.tabs.timetableFeature.isScheduleLimitReached = false
    home.tabs.timetableFeature.setDetail = nil
    home.tabs.timetableFeature.destination = nil
    home.tabs.profile.destination = nil
  }

  private func isBooked(
    _ id: String,
    in festival: FestivalCoordinator.State
  ) -> Bool {
    guard let screen = festival.routes.last(where: {
      !$0.screen.is(\.bearerBoard) && !$0.screen.is(\.notificationInbox)
    })?.screen else { return false }
    switch screen {
    case let .festivalList(list): return list.bookedFestivalIDs.contains(id)
    case let .liveBoard(board): return board.bookedFestivalIDs.contains(id)
    case .bearerBoard, .notificationInbox: return false
    }
  }
}
