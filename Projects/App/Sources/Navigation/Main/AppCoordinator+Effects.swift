//
//  AppCoordinator+Effects.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import CoreAssembly
import FestiCoreAnalyticsInterface
import FestiCoreUtility
import Foundation
import OSLog

// MARK: - 홈 상태 접근

extension AppCoordinator.State {
  /// 홈일 때만 홈 상태를 고치고 다시 저장한다. 홈이 아니면 아무것도 하지 않는다.
  mutating func withHome(
    _ body: (inout MainTabCoordinator.State) -> Effect<AppCoordinator.Action>
  ) -> Effect<AppCoordinator.Action> {
    guard case var .home(home) = self else { return .none }
    defer { self = .home(home) }
    return body(&home)
  }
}

// MARK: - 로그인·프로필

extension AppCoordinator {
  func fetchProfile(generation: Int) -> Effect<Action> {
    return .run { send in
      let isLoggedIn = await authService.isLoggedIn
      let userID = await authService.currentUserID
      await send(.inner(.sessionRestored(
        generation: generation,
        userID: userID,
        isLoggedIn: isLoggedIn
      )))
      guard isLoggedIn else {
        await send(.inner(.profileLoaded(
          generation: generation,
          .failure(.notAuthenticated)
        )))
        return
      }
      do {
        let profile = try await authUseCase.fetchProfile()
        await send(.inner(.profileLoaded(
          generation: generation,
          .success(profile)
        )))
      } catch {
        await send(.inner(.profileLoaded(
          generation: generation,
          .failure(authFailure(error))
        )))
      }
    }
  }

  /// 도메인이 매핑하지 않은 오류는 계정 요청 실패로 본다.
  func authFailure(_ error: any Error) -> AuthDomainError {
    return error as? AuthDomainError ?? .unavailable
  }

  /// 확인한 계정을 비우고 새 세대로 프로필을 다시 읽는다. 예약 목록은 비로그인 기준으로 먼저 다시 읽는다.
  func recheckProfile(home: inout MainTabCoordinator.State) -> Effect<Action> {
    let generation = home.authFlow.beginRequest()
    home.authFlow.profile = nil
    home.authFlow.verifiedUserID = nil
    return .merge(
      fetchProfile(generation: generation),
      reloadBookmarks(userID: nil)
    )
  }

  /// 시트가 열려 있고 현재 세대의 로그인 시도일 때만 결과를 받아들인다.
  func isActiveLoginAttempt(_ flow: AuthFlow) -> Bool {
    return flow.presentation == .login && flow.loginAttemptGeneration == flow.generation
  }

  func acceptLogin(
    _ result: AuthLoginResult,
    home: inout MainTabCoordinator.State
  ) -> Effect<Action> {
    if home.authFlow.isAccountChanged(to: result.user.id) { home.authFlow.clearPendingBookmark() }
    home.authFlow.dropPendingBookmark(notOwnedBy: result.user.id)
    home.authFlow.verifiedUserID = result.user.id
    home.authFlow.hasSession = true
    home.authFlow.profile = nil
    home.authFlow.presentation = nil
    home.authFlow.loginAttemptGeneration = nil
    // 로그인이 확정된 직후 사용자 ID를 분석 도구에 연결하고, 신규 계정이면 sign_up을 남긴다.
    analyticsUseCase.identify(
      result.user.id,
      result.user.provider
    )
    if result.newUser, let provider = AnalyticsProvider(rawValue: result.user.provider) {
      analyticsUseCase.track(.signUp(method: provider))
    }
    return fetchProfile(generation: home.authFlow.beginRequest())
  }

  func finishEligible(home: inout MainTabCoordinator.State) -> Effect<Action> {
    guard let profile = home.authFlow.profile, profile.isEligible else { return .none }
    let userID = profile.user.id
    bookedStore.setOfflineEligible(
      userID,
      true
    )
    home.authFlow.verifiedUserID = userID
    home.authFlow.lastVerifiedUserID = userID
    home.authFlow.resetSignUpRetryState()
    if !bookedStore.legacyBookmarks().isEmpty {
      home.authFlow.presentation = .migration
      return .none
    }
    home.authFlow.presentation = nil
    return completePendingBookmark(
      home.authFlow.takePendingBookmark(),
      userID: userID
    )
  }
}

// MARK: - 예약

extension AppCoordinator {
  /// 대기 예약이 있으면 그 계정으로 마저 반영하고, 없으면 예약 목록만 다시 읽는다.
  func completePendingBookmark(
    _ pending: AuthFlow.PendingBookmark?,
    userID: String
  ) -> Effect<Action> {
    guard let pending else { return reloadBookmarks(userID: userID) }
    return .send(.scope(.home(.completePendingBookmark(
      id: pending.id,
      userID: userID,
      shouldBeBooked: pending.shouldBeBooked
    ))))
  }

  func reloadBookmarks(userID: String?) -> Effect<Action> {
    return .send(.scope(.home(.festival(.reloadBookmarks(userID: userID)))))
  }

  func isBooked(
    _ id: String,
    in festival: FestivalCoordinator.State
  ) -> Bool {
    let board = festival.routes.last { $0.screen.festivalBoard != nil }?.screen.festivalBoard
    return board?.bookedFestivalIDs.contains(id) ?? false
  }
}

// MARK: - 계정 데이터

extension AppCoordinator {
  /// 이전 계정의 라이브 보드·예약 목록을 바로 비운다.
  func clearAccountData(_ home: inout MainTabCoordinator.State) -> Effect<Action> {
    clearAccountDisplayData(&home)
    return notifyAccountChanged()
  }

  /// 축제 화면에 계정이 바뀌었다고 알려 예약 목록을 다시 정리하게 한다.
  func notifyAccountChanged() -> Effect<Action> {
    return .send(.scope(.home(.festival(.accountChanged))))
  }

  /// 비동기 입력 액션 전에 개인 데이터가 화면에 남지 않도록 동기 정리한다.
  func clearAccountDisplayData(_ home: inout MainTabCoordinator.State) {
    home.festivalState.clearAccountData()
    home.flagState.clearAccountData()
    home.timetableState.mySetIDs = []
    home.timetableState.scheduleSync = .idle
    home.timetableState.isScheduleLimitReached = false
    home.timetableState.setDetail = nil
    home.timetableState.destination = nil
    home.profileState.destination = nil
  }
}

// MARK: - 로그아웃·탈퇴

extension AppCoordinator {
  func myAccountOperation(
    state: inout State,
    operation: MyAccountOperation
  ) -> Effect<Action> {
    return state.withHome { home in
      guard home.authFlow.hasSession, !home.authFlow.isLoading else { return .none }
      let generation = home.authFlow.beginRequest()
      home.authFlow.accountOperationGeneration = generation
      home.authFlow.accountOperation = operation
      home.authFlow.message = nil
      return runAccountOperation(
        operation,
        generation: generation
      )
    }
  }

  func runAccountOperation(
    _ operation: MyAccountOperation,
    generation: Int
  ) -> Effect<Action> {
    return .run { send in
      do {
        await unbindDeviceForAccountOperation()
        try Task.checkCancellation()
        await endLocalLiveActivities()
        try Task.checkCancellation()
        switch operation {
        case .signOut: try await authUseCase.signOut()
        case .withdraw: try await authUseCase.withdraw()
        }
        await send(.inner(.myAccountFinished(
          generation: generation,
          operation: operation,
          result: .success(())
        )))
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
          result: .failure(authFailure(error))
        )))
      }
    }
    .cancellable(
      id: CancelID.accountOperation,
      cancelInFlight: true
    )
  }
}

// MARK: - 기기·Live Activity

extension AppCoordinator {
  func unbindDeviceForAccountOperation() async {
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
}
