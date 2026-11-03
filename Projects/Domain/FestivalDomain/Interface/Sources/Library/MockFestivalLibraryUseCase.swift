//
//  MockFestivalLibraryUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalLibraryUseCase: FestivalLibraryUseCaseInterface {
  private let bookedFestivalIDsHandler: @Sendable (String) -> Set<String>
  private let recentSearchesHandler: @Sendable (String?) -> [String]
  private let addRecentSearchHandler: @Sendable (String, String?) -> [String]
  private let removeRecentSearchHandler: @Sendable (String, String?) -> [String]
  private let clearRecentSearchesHandler: @Sendable (String?) -> Void

  public init(
    bookedFestivalIDs: @escaping @Sendable (_ userID: String) -> Set<String> = { _ in
      reportIssue("festivalLibraryUseCase.bookedFestivalIDs 미등록")
      return []
    },
    recentSearches: @escaping @Sendable (_ userID: String?) -> [String] = { _ in
      reportIssue("festivalLibraryUseCase.recentSearches 미등록")
      return []
    },
    addRecentSearch: @escaping @Sendable (_ query: String, _ userID: String?) -> [String] = { _, _ in
      reportIssue("festivalLibraryUseCase.addRecentSearch 미등록")
      return []
    },
    removeRecentSearch: @escaping @Sendable (_ query: String, _ userID: String?) -> [String] = { _, _ in
      reportIssue("festivalLibraryUseCase.removeRecentSearch 미등록")
      return []
    },
    clearRecentSearches: @escaping @Sendable (_ userID: String?) -> Void = { _ in
      reportIssue("festivalLibraryUseCase.clearRecentSearches 미등록")
    }
  ) {
    self.bookedFestivalIDsHandler = bookedFestivalIDs
    self.recentSearchesHandler = recentSearches
    self.addRecentSearchHandler = addRecentSearch
    self.removeRecentSearchHandler = removeRecentSearch
    self.clearRecentSearchesHandler = clearRecentSearches
  }

  public func bookedFestivalIDs(for userID: String) -> Set<String> {
    bookedFestivalIDsHandler(userID)
  }

  public func recentSearches(for userID: String?) -> [String] {
    recentSearchesHandler(userID)
  }

  public func addRecentSearch(_ query: String, for userID: String?) -> [String] {
    addRecentSearchHandler(query, userID)
  }

  public func removeRecentSearch(_ query: String, for userID: String?) -> [String] {
    removeRecentSearchHandler(query, userID)
  }

  public func clearRecentSearches(for userID: String?) {
    clearRecentSearchesHandler(userID)
  }
}
