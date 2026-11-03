//
//  FestivalNotificationPermissionClient.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 기기 설정의 알림 허용 상태를 읽는다.
public struct FestivalNotificationPermissionClient: Sendable {
  public var status: @Sendable () async -> FestivalNotificationPermission

  public init(status: @escaping @Sendable () async -> FestivalNotificationPermission) {
    self.status = status
  }
}

extension FestivalNotificationPermissionClient: TestDependencyKey {
  public static let testValue = Self(status: {
    reportIssue("festivalNotificationPermission.status 미등록")
    return .notDetermined
  })
}

public extension DependencyValues {
  var festivalNotificationPermission: FestivalNotificationPermissionClient {
    get { self[FestivalNotificationPermissionClient.self] }
    set { self[FestivalNotificationPermissionClient.self] = newValue }
  }
}
