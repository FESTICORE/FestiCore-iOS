//
//  FestivalLibraryUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

public struct FestivalLibraryUseCaseImpl: FestivalLibraryUseCaseInterface {
  @Dependency(\.festivalBookedStore) private var bookedStore
  @Dependency(\.festivalRecentSearchStore) private var recentSearchStore

  public init() {}

  public func bookedFestivalIDs(for userID: String) -> Set<String> {
    bookedStore.load(for: userID)
  }

  public func recentSearches(for userID: String?) -> [String] {
    recentSearchStore.load(for: userID)
  }

  public func addRecentSearch(_ query: String, for userID: String?) -> [String] {
    recentSearchStore.add(query, for: userID)
  }

  public func removeRecentSearch(_ query: String, for userID: String?) -> [String] {
    recentSearchStore.remove(query, for: userID)
  }

  public func clearRecentSearches(for userID: String?) {
    recentSearchStore.clear(for: userID)
  }
}
