//
//  FestivalPackLocalStore.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 축제별 내 준비물과 팩 받기 설정을 기기에 저장한다.
public struct FestivalPackLocalStore: Sendable {
  public var loadChecklist: @Sendable (_ festivalID: String) -> FestivalChecklist
  public var saveChecklist: @Sendable (_ checklist: FestivalChecklist, _ festivalID: String) -> Void
  public var autoDownloadOnWiFi: @Sendable () -> Bool
  public var setAutoDownloadOnWiFi: @Sendable (Bool) -> Void

  public init(
    loadChecklist: @escaping @Sendable (_ festivalID: String) -> FestivalChecklist,
    saveChecklist: @escaping @Sendable (_ checklist: FestivalChecklist, _ festivalID: String) -> Void,
    autoDownloadOnWiFi: @escaping @Sendable () -> Bool,
    setAutoDownloadOnWiFi: @escaping @Sendable (Bool) -> Void
  ) {
    self.loadChecklist = loadChecklist
    self.saveChecklist = saveChecklist
    self.autoDownloadOnWiFi = autoDownloadOnWiFi
    self.setAutoDownloadOnWiFi = setAutoDownloadOnWiFi
  }
}

extension FestivalPackLocalStore: TestDependencyKey {
  public static let testValue = Self(
    loadChecklist: { _ in
      reportIssue("festivalPackLocalStore.loadChecklist 미등록")
      return FestivalChecklist()
    },
    saveChecklist: { _, _ in reportIssue("festivalPackLocalStore.saveChecklist 미등록") },
    autoDownloadOnWiFi: {
      reportIssue("festivalPackLocalStore.autoDownloadOnWiFi 미등록")
      return false
    },
    setAutoDownloadOnWiFi: { _ in reportIssue("festivalPackLocalStore.setAutoDownloadOnWiFi 미등록") }
  )
}

public extension DependencyValues {
  var festivalPackLocalStore: FestivalPackLocalStore {
    get { self[FestivalPackLocalStore.self] }
    set { self[FestivalPackLocalStore.self] = newValue }
  }
}
