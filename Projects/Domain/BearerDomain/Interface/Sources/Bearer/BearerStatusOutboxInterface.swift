//
//  BearerStatusOutboxInterface.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import Foundation
import IssueReporting

/// 기수 상태 변경 대기열. 보드를 닫거나 앱을 다시 켜도 남아 있고, 누른 순서대로 같은 멱등키로 보낸다.
public protocol BearerStatusOutboxInterface: Sendable {
  func enqueue(flagID: String, request: BearerStatusRequest) async
  func pending(flagID: String) async -> [BearerStatusRequest]
  func events(flagID: String) async -> AsyncStream<BearerOutboxEvent>
  /// 멈춘 전송(로그인 필요·재시도 한도)을 다시 시작한다.
  func resume() async
}

public enum BearerStatusOutboxDependency: TestDependencyKey {
  public static var testValue: any BearerStatusOutboxInterface { MockBearerStatusOutbox() }
  public static var previewValue: any BearerStatusOutboxInterface { testValue }
}

public extension DependencyValues {
  var bearerStatusOutbox: any BearerStatusOutboxInterface {
    get { self[BearerStatusOutboxDependency.self] }
    set { self[BearerStatusOutboxDependency.self] = newValue }
  }
}

/// 주입하지 않은 대기열. 호출하면 테스트 이슈를 남긴다.
public struct MockBearerStatusOutbox: BearerStatusOutboxInterface {
  public init() {}

  public func enqueue(flagID: String, request: BearerStatusRequest) async {
    reportIssue("bearerStatusOutbox 미등록")
  }

  public func pending(flagID: String) async -> [BearerStatusRequest] {
    reportIssue("bearerStatusOutbox 미등록")
    return []
  }

  public func events(flagID: String) async -> AsyncStream<BearerOutboxEvent> {
    reportIssue("bearerStatusOutbox 미등록")
    return AsyncStream { $0.finish() }
  }

  public func resume() async {
    reportIssue("bearerStatusOutbox 미등록")
  }
}
