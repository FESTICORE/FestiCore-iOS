//
//  FestivalPackExpiryTests.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/13/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

/// Figma Pack D·E·F: 페스티벌이 끝나고 30일 뒤에 팩만 자동으로 지우고 내 일정과 체크한 준비물은 남긴다.
struct FestivalPackExpiryTests {
  /// 마지막 날 종료 시각 2026-11-01T14:00:00Z
  private let lastDayEnd = Date(timeIntervalSince1970: 1_793_541_600)
  private let day: TimeInterval = 24 * 60 * 60

  @Test func keepsPackUntilThirtyDaysAfterLastDayEnds() async throws {
    let repository = ExpiryPackRepository(packs: [
      pack(
        "fst_a",
        days: ["2026-10-31T14:00:00Z", "2026-11-01T14:00:00Z"]
      ),
    ])

    let beforeBoundary = lastDayEnd.addingTimeInterval(30 * day - 1)
    #expect(try await deleteExpired(
      repository: repository,
      now: lastDayEnd.addingTimeInterval(29 * day)
    ) == [])
    #expect(try await deleteExpired(
      repository: repository,
      now: beforeBoundary
    ) == [])
    #expect(repository.deletedIDs.value.isEmpty)

    #expect(try await deleteExpired(
      repository: repository,
      now: lastDayEnd.addingTimeInterval(30 * day)
    ) == ["fst_a"])
    #expect(repository.deletedIDs.value == ["fst_a"])
  }

  @Test func usesLastDayEndAcrossUnorderedDays() async throws {
    let repository = ExpiryPackRepository(packs: [
      pack(
        "fst_a",
        days: ["2026-11-01T14:00:00.000Z", "2026-10-20T14:00:00.000Z"]
      ),
    ])

    // 첫날 기준으로는 30일이 지났지만 마지막 날 기준으로는 아직이다.
    #expect(try await deleteExpired(
      repository: repository,
      now: lastDayEnd.addingTimeInterval(29 * day)
    ) == [])
  }

  @Test func keepsPackWithoutKnownEndTime() async throws {
    let repository = ExpiryPackRepository(packs: [
      CachedFestivalPack(
        festivalID: "no_days",
        packVersion: 1,
        etag: "e",
        pack: Data(#"{"id":"no_days"}"#.utf8)
      ),
      CachedFestivalPack(
        festivalID: "empty_days",
        packVersion: 1,
        etag: "e",
        pack: Data(#"{"id":"empty_days","days":[]}"#.utf8)
      ),
      CachedFestivalPack(
        festivalID: "missing_last",
        packVersion: 1,
        etag: "e",
        pack: Data(#"{"id":"missing_last","days":[{"endsAt":"2026-10-01T14:00:00Z"},{"date":"2026-10-02"}]}"#.utf8)
      ),
      CachedFestivalPack(
        festivalID: "broken",
        packVersion: 1,
        etag: "e",
        pack: Data("not json".utf8)
      ),
    ])

    #expect(try await deleteExpired(
      repository: repository,
      now: lastDayEnd.addingTimeInterval(365 * day)
    ) == [])
    #expect(repository.deletedIDs.value.isEmpty)
  }

  @Test func deletesOnlyPackAndKeepsScheduleAndChecklist() async throws {
    let repository = ExpiryPackRepository(packs: [
      pack(
        "fst_old",
        days: ["2026-11-01T14:00:00Z"]
      ),
      pack(
        "fst_new",
        days: ["2026-12-01T14:00:00Z"]
      ),
    ])
    let checklist = FestivalChecklist(
      checkedIDs: ["water"],
      customItems: [.init(
        id: "custom",
        label: "보조배터리"
      )]
    )
    let checklists = LockIsolated(["fst_old": checklist])
    let bookmarks = LockIsolated(["user_a": Set(["fst_old"])])

    let deleted = try await withDependencies {
      $0.date.now = lastDayEnd.addingTimeInterval(30 * day)
      $0.festivalPackSyncRepository = repository
      $0.festivalPackLocalStore = FestivalPackLocalStore(
        loadChecklist: { festivalID in return checklists.value[festivalID] ?? FestivalChecklist() },
        saveChecklist: { value, festivalID in checklists.withValue { $0[festivalID] = value } },
        autoDownloadOnWiFi: { return true },
        setAutoDownloadOnWiFi: { _ in }
      )
      $0.festivalBookedStore = FestivalBookedStore(
        load: { userID in return bookmarks.value[userID] ?? [] },
        save: { ids, userID in bookmarks.withValue { $0[userID] = ids } }
      )
    } operation: {
      return try await FestivalPackUseCaseImpl().deleteExpiredPacks()
    }

    #expect(deleted == ["fst_old"])
    #expect(repository.deletedIDs.value == ["fst_old"])
    #expect(checklists.value["fst_old"] == checklist)
    #expect(bookmarks.value["user_a"] == ["fst_old"])
  }

  @Test func failedDeletionDoesNotStopOtherPacks() async throws {
    let repository = ExpiryPackRepository(
      packs: [
        pack(
          "fst_fail",
          days: ["2026-11-01T14:00:00Z"]
        ),
        pack(
          "fst_ok",
          days: ["2026-11-01T14:00:00Z"]
        ),
      ],
      failingIDs: ["fst_fail"]
    )

    #expect(try await deleteExpired(
      repository: repository,
      now: lastDayEnd.addingTimeInterval(31 * day)
    ) == ["fst_ok"])
  }
}

private extension FestivalPackExpiryTests {
  func deleteExpired(
    repository: ExpiryPackRepository,
    now: Date
  ) async throws -> [String] {
    return try await withDependencies {
      $0.date.now = now
      $0.festivalPackSyncRepository = repository
    } operation: {
      return try await FestivalPackUseCaseImpl().deleteExpiredPacks()
    }
  }

  func pack(
    _ festivalID: String,
    days: [String]
  ) -> CachedFestivalPack {
    let dayJSON = days.map { #"{"endsAt":"\#($0)"}"# }.joined(separator: ",")
    return CachedFestivalPack(
      festivalID: festivalID,
      packVersion: 1,
      etag: "e",
      pack: Data(#"{"id":"\#(festivalID)","days":[\#(dayJSON)]}"#.utf8)
    )
  }
}

private final class ExpiryPackRepository: FestivalPackSyncRepositoryInterface, @unchecked Sendable {
  let packs: [CachedFestivalPack]
  let failingIDs: Set<String>
  let deletedIDs = LockIsolated<[String]>([])

  init(
    packs: [CachedFestivalPack],
    failingIDs: Set<String> = []
  ) {
    self.packs = packs
    self.failingIDs = failingIDs
  }

  func cachedPacks() async throws -> [CachedFestivalPack] {
    let deleted = Set(deletedIDs.value)
    return packs.filter { !deleted.contains($0.festivalID) }
  }

  func packUpdates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    return AsyncThrowingStream { $0.finish() }
  }

  func downloadPack(for _: String) -> AsyncThrowingStream<PackDownloadEvent, Error> {
    return AsyncThrowingStream { $0.finish() }
  }

  func deletePack(for festivalID: String) async throws {
    if failingIDs.contains(festivalID) { throw FestivalPackError.offline }
    deletedIDs.withValue { $0.append(festivalID) }
  }
}
