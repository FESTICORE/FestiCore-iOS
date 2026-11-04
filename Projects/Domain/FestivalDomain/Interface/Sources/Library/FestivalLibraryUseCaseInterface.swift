//
//  FestivalLibraryUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 계정별로 저장한 예약 축제와 최근 검색어를 다룬다. `userID`가 없으면 비로그인 기록이다.
public protocol FestivalLibraryUseCaseInterface: Sendable {
  /// 사용자가 예매한 축제 ID를 기기에서 읽는다.
  func bookedFestivalIDs(for userID: String) -> Set<String>
  /// 사용자별 최근 검색어를 기기에서 읽는다.
  func recentSearches(for userID: String?) -> [String]
  /// 검색어를 맨 앞에 넣고 바뀐 목록을 돌려준다.
  func addRecentSearch(_ query: String, for userID: String?) -> [String]
  /// 검색어를 지우고 바뀐 목록을 돌려준다.
  func removeRecentSearch(_ query: String, for userID: String?) -> [String]
  /// 사용자별 최근 검색어를 모두 지운다.
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
