//
//  MockMapAppClient.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/12/26.
//

import Dependencies

/// 테스트에서 설치 여부를 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록하고 설치되지 않았다고 답한다.
public struct MockMapAppClient: MapAppClient {
  public var isInstalledHandler: @Sendable (MapApp) async -> Bool

  public init(
    isInstalled: @escaping @Sendable (MapApp) async -> Bool = { _ in
      reportIssue("mapAppClient.isInstalled 미등록")
      return false
    }
  ) {
    isInstalledHandler = isInstalled
  }

  public func isInstalled(_ app: MapApp) async -> Bool {
    return await isInstalledHandler(app)
  }
}
