//
//  FestivalImageUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import Foundation

/// 축제 이미지 주소를 검증하고 미리 받아 둔다.
public protocol FestivalImageUseCaseInterface: Sendable {
  /// 쓸 수 있는 https 이미지 주소만 돌려준다.
  func imageURL(for value: String?) -> URL?
  /// 화면에 필요한 이미지 주소를 미리 받아 둔다.
  func startPrefetch(_ urls: [URL]) async
  /// 진행 중인 이미지 미리 받기를 중단한다.
  func stopPrefetch() async
}

public enum FestivalImageUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalImageUseCaseInterface { MockFestivalImageUseCase() }
  public static var previewValue: any FestivalImageUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalImageUseCase: any FestivalImageUseCaseInterface {
    get { self[FestivalImageUseCaseDependency.self] }
    set { self[FestivalImageUseCaseDependency.self] = newValue }
  }
}
