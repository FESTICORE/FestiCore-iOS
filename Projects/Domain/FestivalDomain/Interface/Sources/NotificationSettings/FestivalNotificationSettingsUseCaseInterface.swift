//
//  FestivalNotificationSettingsUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 설정 > 알림 화면의 기기 알림 허용 상태와 알림 종류 설정
public protocol FestivalNotificationSettingsUseCaseInterface: Sendable {
  func permission() async -> FestivalNotificationPermission
  func settings() async throws -> FestivalNotificationSettings
  /// 바뀐 항목만 저장하고 서버가 돌려준 전체 설정을 반환한다.
  func updateSettings(_ changes: [FestivalNotificationKind: Bool]) async throws -> FestivalNotificationSettings
}

public enum FestivalNotificationSettingsUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalNotificationSettingsUseCaseInterface {
    MockFestivalNotificationSettingsUseCase()
  }
  public static var previewValue: any FestivalNotificationSettingsUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalNotificationSettingsUseCase: any FestivalNotificationSettingsUseCaseInterface {
    get { self[FestivalNotificationSettingsUseCaseDependency.self] }
    set { self[FestivalNotificationSettingsUseCaseDependency.self] = newValue }
  }
}

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalNotificationSettingsUseCase: FestivalNotificationSettingsUseCaseInterface {
  private let permissionHandler: @Sendable () async -> FestivalNotificationPermission
  private let settingsHandler: @Sendable () async throws -> FestivalNotificationSettings
  private let updateHandler: @Sendable ([FestivalNotificationKind: Bool]) async throws -> FestivalNotificationSettings

  public init(
    permission: @escaping @Sendable () async -> FestivalNotificationPermission = {
      reportIssue("festivalNotificationSettingsUseCase.permission 미등록")
      return .notDetermined
    },
    settings: @escaping @Sendable () async throws -> FestivalNotificationSettings = {
      reportIssue("festivalNotificationSettingsUseCase.settings 미등록")
      throw FestivalNotificationSettingsError.notRegistered
    },
    updateSettings: @escaping @Sendable ([FestivalNotificationKind: Bool]) async throws
      -> FestivalNotificationSettings = { _ in
      reportIssue("festivalNotificationSettingsUseCase.updateSettings 미등록")
      throw FestivalNotificationSettingsError.notRegistered
    }
  ) {
    permissionHandler = permission
    settingsHandler = settings
    updateHandler = updateSettings
  }

  public func permission() async -> FestivalNotificationPermission { await permissionHandler() }
  public func settings() async throws -> FestivalNotificationSettings { try await settingsHandler() }
  public func updateSettings(_ changes: [FestivalNotificationKind: Bool]) async throws -> FestivalNotificationSettings {
    try await updateHandler(changes)
  }
}
