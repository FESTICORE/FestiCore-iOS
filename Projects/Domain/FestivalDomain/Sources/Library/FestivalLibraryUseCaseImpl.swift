//
//  FestivalLibraryUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

/// 사용자별 예매 기록과 최근 검색 기록을 관리한다.
public struct FestivalLibraryUseCaseImpl: FestivalLibraryUseCaseInterface {
  @Dependency(\.festivalBookedStore) private var bookedStore
  @Dependency(\.festivalRecentSearchStore) private var recentSearchStore

  public init() {}

  /// 기기에 저장된 사용자의 예매 축제 ID를 읽는다.
  public func bookedFestivalIDs(for userID: String) -> Set<String> {
    return bookedStore.load(for: userID)
  }

  /// 축제 예매 상태를 로컬 저장소에 반영한다.
  public func setBooked(
    _ booked: Bool,
    festivalID: String,
    for userID: String
  ) -> Set<String> {
    return bookedStore.setBookmark(
      festivalID,
      booked: booked,
      for: userID)
  }

  /// 저장된 계정별 오프라인 예매 자격을 확인한다.
  public func isOfflineBookingEligible(userID: String) -> Bool {
    return bookedStore.offlineEligible(userID)
  }

  /// 계정별 오프라인 예매 자격을 저장한다.
  public func setOfflineBookingEligibility(
    _ isEligible: Bool,
    for userID: String
  ) {
    bookedStore.setOfflineEligible(
      userID,
      isEligible)
  }

  /// 이전 버전의 계정 미지정 예매 목록을 읽는다.
  public func legacyBookmarks() -> Set<String> {
    return bookedStore.legacyBookmarks()
  }

  /// 이전 버전 예매 목록의 이전 여부를 저장한다.
  public func resolveLegacyBookmarkMigration(
    accepted: Bool,
    userID: String
  ) {
    bookedStore.resolveLegacyMigration(
      accepted: accepted,
      for: userID)
  }

  /// 로그인 또는 비로그인 사용자의 최근 검색어를 읽는다.
  public func recentSearches(for userID: String?) -> [String] {
    recentSearchStore.load(for: userID)
  }

  /// 검색어를 최근 목록 앞에 저장하고 전체 목록을 돌려준다.
  public func addRecentSearch(_ query: String, for userID: String?) -> [String] {
    recentSearchStore.add(
      query,
      for: userID)
  }

  /// 검색어 하나를 삭제하고 남은 목록을 돌려준다.
  public func removeRecentSearch(_ query: String, for userID: String?) -> [String] {
    recentSearchStore.remove(
      query,
      for: userID)
  }

  /// 해당 사용자의 검색 기록을 모두 삭제한다.
  public func clearRecentSearches(for userID: String?) {
    recentSearchStore.clear(for: userID)
  }
}
