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
    bookedStore.load(for: userID)
  }

  /// 로그인 또는 비로그인 사용자의 최근 검색어를 읽는다.
  public func recentSearches(for userID: String?) -> [String] {
    recentSearchStore.load(for: userID)
  }

  /// 검색어를 최근 목록 앞에 저장하고 전체 목록을 돌려준다.
  public func addRecentSearch(_ query: String, for userID: String?) -> [String] {
    recentSearchStore.add(query, for: userID)
  }

  /// 검색어 하나를 삭제하고 남은 목록을 돌려준다.
  public func removeRecentSearch(_ query: String, for userID: String?) -> [String] {
    recentSearchStore.remove(query, for: userID)
  }

  /// 해당 사용자의 검색 기록을 모두 삭제한다.
  public func clearRecentSearches(for userID: String?) {
    recentSearchStore.clear(for: userID)
  }
}
