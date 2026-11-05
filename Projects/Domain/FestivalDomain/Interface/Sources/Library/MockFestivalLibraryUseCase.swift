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
  private let setBookedHandler: @Sendable (
    Bool,
    String,
    String) -> Set<String>
  private let isOfflineBookingEligibleHandler: @Sendable (String) -> Bool
  private let setOfflineBookingEligibilityHandler: @Sendable (
    Bool,
    String) -> Void
  private let legacyBookmarksHandler: @Sendable () -> Set<String>
  private let resolveLegacyBookmarkMigrationHandler: @Sendable (
    Bool,
    String) -> Void
  private let recentSearchesHandler: @Sendable (String?) -> [String]
  private let addRecentSearchHandler: @Sendable (
    String,
    String?) -> [String]
  private let removeRecentSearchHandler: @Sendable (
    String,
    String?) -> [String]
  private let clearRecentSearchesHandler: @Sendable (String?) -> Void

  public init(
    bookedFestivalIDs: @escaping @Sendable (_ userID: String) -> Set<String> = { _ in
      reportIssue("festivalLibraryUseCase.bookedFestivalIDs 미등록")
      return []
    },
    setBooked: @escaping @Sendable (
      _ booked: Bool,
      _ festivalID: String,
      _ userID: String
    ) -> Set<String> = { _, _, _ in
      reportIssue("festivalLibraryUseCase.setBooked 미등록")
      return []
    },
    isOfflineBookingEligible: @escaping @Sendable (_ userID: String) -> Bool = { _ in
      reportIssue("festivalLibraryUseCase.isOfflineBookingEligible 미등록")
      return false
    },
    setOfflineBookingEligibility: @escaping @Sendable (
      _ isEligible: Bool,
      _ userID: String
    ) -> Void = { _, _ in
      reportIssue("festivalLibraryUseCase.setOfflineBookingEligibility 미등록")
    },
    legacyBookmarks: @escaping @Sendable () -> Set<String> = {
      reportIssue("festivalLibraryUseCase.legacyBookmarks 미등록")
      return []
    },
    resolveLegacyBookmarkMigration: @escaping @Sendable (
      _ accepted: Bool,
      _ userID: String
    ) -> Void = { _, _ in
      reportIssue("festivalLibraryUseCase.resolveLegacyBookmarkMigration 미등록")
    },
    recentSearches: @escaping @Sendable (_ userID: String?) -> [String] = { _ in
      reportIssue("festivalLibraryUseCase.recentSearches 미등록")
      return []
    },
    addRecentSearch: @escaping @Sendable (
      _ query: String,
      _ userID: String?) -> [String] = { _, _ in
      reportIssue("festivalLibraryUseCase.addRecentSearch 미등록")
      return []
    },
    removeRecentSearch: @escaping @Sendable (
      _ query: String,
      _ userID: String?) -> [String] = { _, _ in
      reportIssue("festivalLibraryUseCase.removeRecentSearch 미등록")
      return []
    },
    clearRecentSearches: @escaping @Sendable (_ userID: String?) -> Void = { _ in
      reportIssue("festivalLibraryUseCase.clearRecentSearches 미등록")
    }
  ) {
    self.bookedFestivalIDsHandler = bookedFestivalIDs
    self.setBookedHandler = setBooked
    self.isOfflineBookingEligibleHandler = isOfflineBookingEligible
    self.setOfflineBookingEligibilityHandler = setOfflineBookingEligibility
    self.legacyBookmarksHandler = legacyBookmarks
    self.resolveLegacyBookmarkMigrationHandler = resolveLegacyBookmarkMigration
    self.recentSearchesHandler = recentSearches
    self.addRecentSearchHandler = addRecentSearch
    self.removeRecentSearchHandler = removeRecentSearch
    self.clearRecentSearchesHandler = clearRecentSearches
  }

  public func bookedFestivalIDs(for userID: String) -> Set<String> {
    bookedFestivalIDsHandler(userID)
  }

  public func setBooked(
    _ booked: Bool,
    festivalID: String,
    for userID: String
  ) -> Set<String> {
    return setBookedHandler(
      booked,
      festivalID,
      userID)
  }

  public func isOfflineBookingEligible(userID: String) -> Bool {
    return isOfflineBookingEligibleHandler(userID)
  }

  public func setOfflineBookingEligibility(
    _ isEligible: Bool,
    for userID: String
  ) {
    setOfflineBookingEligibilityHandler(
      isEligible,
      userID)
  }

  public func legacyBookmarks() -> Set<String> {
    return legacyBookmarksHandler()
  }

  public func resolveLegacyBookmarkMigration(
    accepted: Bool,
    userID: String
  ) {
    resolveLegacyBookmarkMigrationHandler(
      accepted,
      userID)
  }

  public func recentSearches(for userID: String?) -> [String] {
    recentSearchesHandler(userID)
  }

  public func addRecentSearch(_ query: String, for userID: String?) -> [String] {
    addRecentSearchHandler(
      query,
      userID)
  }

  public func removeRecentSearch(_ query: String, for userID: String?) -> [String] {
    removeRecentSearchHandler(
      query,
      userID)
  }

  public func clearRecentSearches(for userID: String?) {
    clearRecentSearchesHandler(userID)
  }
}
