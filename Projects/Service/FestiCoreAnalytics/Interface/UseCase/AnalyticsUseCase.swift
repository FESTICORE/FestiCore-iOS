//
//  AnalyticsUseCase.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

import ComposableArchitecture

// MARK: - UseCase

/// 사용자 동작 추적 계약.
public struct AnalyticsUseCase: Sendable {
  /// 앱 시작 시 공통 슈퍼 프로퍼티(os_type/app_version/build) 등록.
  public var registerBaseProperties: @Sendable () -> Void
  /// 로그인 확정 직후 사용자 ID 연결과 로그인 슈퍼·사용자 프로퍼티 설정.
  public var identify: @Sendable (_ userID: String, _ method: String?) -> Void
  /// 핵심 이벤트 추적.
  public var track: @Sendable (_ event: AnalyticsEvent) -> Void
  /// 로그아웃·탈퇴 시 계정 분리(reset)와 공통 프로퍼티 재등록.
  public var reset: @Sendable () -> Void

  public init(
    registerBaseProperties: @escaping @Sendable () -> Void,
    identify: @escaping @Sendable (_ userID: String, _ method: String?) -> Void,
    track: @escaping @Sendable (_ event: AnalyticsEvent) -> Void,
    reset: @escaping @Sendable () -> Void
  ) {
    self.registerBaseProperties = registerBaseProperties
    self.identify = identify
    self.track = track
    self.reset = reset
  }
}

/// 테스트·프리뷰 기본값은 인터페이스가 갖는다. `liveValue`는 구현 모듈이 `DependencyKey`로 채운다.
extension AnalyticsUseCase: TestDependencyKey {
  /// 주입하지 않은 호출은 테스트 이슈로 기록한다.
  /// `registerBaseProperties`는 테스트 호스트로 뜬 앱의 `AppDelegate`가 부르므로 기록하지 않는다.
  public static let testValue = AnalyticsUseCase(
    registerBaseProperties: {},
    identify: { _, _ in reportIssue("analyticsUseCase.identify 미주입") },
    track: { _ in reportIssue("analyticsUseCase.track 미주입") },
    reset: { reportIssue("analyticsUseCase.reset 미주입") }
  )
  public static let previewValue = AnalyticsUseCase(
    registerBaseProperties: {},
    identify: { _, _ in },
    track: { _ in },
    reset: {}
  )
}

public extension DependencyValues {
  var analyticsUseCase: AnalyticsUseCase {
    get { self[AnalyticsUseCase.self] }
    set { self[AnalyticsUseCase.self] = newValue }
  }
}
