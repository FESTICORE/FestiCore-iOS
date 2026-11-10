//
//  AccountDeviceSync.swift
//  FestiCore
//

import ComposableArchitecture
import CoreAssembly
import FestiCoreDeviceInterface
import FestiCoreUtility
import FestivalDomainInterface
import Foundation
import OSLog

/// 계정이 바뀔 때 기기 소유권과 이 기기의 Live Activity를 맞춘다. 세션·계정 코디네이터가 함께 쓴다.
struct AccountDeviceSync {
  @Dependency(\.deviceRegistrationService) var deviceRegistrationService
  @Dependency(\.festivalLiveActivityUseCase) var festivalLiveActivityUseCase

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

  /// 로그인을 잃은 기기의 소유권을 되돌리고 이전 계정의 Live Activity를 끝낸다.
  func releaseSignedOutDevice() async {
    try? await deviceRegistrationService.recoverBoundDevice()
    await endLocalLiveActivities()
  }

  func endLocalLiveActivities() async {
    for activity in await festivalLiveActivityUseCase.activities() {
      await festivalLiveActivityUseCase.end(activityID: activity.id)
    }
  }
}
