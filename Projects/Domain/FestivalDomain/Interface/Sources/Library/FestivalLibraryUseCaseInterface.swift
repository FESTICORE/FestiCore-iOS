//
//  FestivalLibraryUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 계정별로 저장한 예약 축제와 최근 검색어를 다룬다. `userID`가 없으면 비로그인 기록이다.
public protocol FestivalLibraryUseCaseInterface: Sendable {
  func bookedFestivalIDs(for userID: String) -> Set<String>
  func recentSearches(for userID: String?) -> [String]
  /// 검색어를 맨 앞에 넣고 바뀐 목록을 돌려준다.
  func addRecentSearch(_ query: String, for userID: String?) -> [String]
  /// 검색어를 지우고 바뀐 목록을 돌려준다.
  func removeRecentSearch(_ query: String, for userID: String?) -> [String]
  func clearRecentSearches(for userID: String?)
}

public enum FestivalLibraryUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalLibraryUseCaseInterface { MockFestivalLibraryUseCase() }
  public static var previewValue: any FestivalLibraryUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalLibraryUseCase: any FestivalLibraryUseCaseInterface {
    get { self[FestivalLibraryUseCaseDependency.self] }
    set { self[FestivalLibraryUseCaseDependency.self] = newValue }
  }
}
