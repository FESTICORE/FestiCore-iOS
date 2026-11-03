//
//  FestivalReceivedPackUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 마이 화면의 받은 팩 목록을 만든다.
public protocol FestivalReceivedPackUseCaseInterface: Sendable {
  /// 기기에 받은 팩. 새 버전 여부는 저장된 축제 목록으로 판단하고 네트워크에 연결하지 않는다.
  func receivedPacks() async throws -> [FestivalReceivedPack]
  /// 축제 목록을 서버에서 다시 받아 새 버전 여부를 갱신한다.
  func refreshReceivedPacks() async throws -> [FestivalReceivedPack]
}

public enum FestivalReceivedPackUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalReceivedPackUseCaseInterface { MockFestivalReceivedPackUseCase() }
  public static var previewValue: any FestivalReceivedPackUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalReceivedPackUseCase: any FestivalReceivedPackUseCaseInterface {
    get { self[FestivalReceivedPackUseCaseDependency.self] }
    set { self[FestivalReceivedPackUseCaseDependency.self] = newValue }
  }
}
