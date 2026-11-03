//
//  MockFestivalPackDetailUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 비동기 호출은 테스트 이슈로 기록한다.
public struct MockFestivalPackDetailUseCase: FestivalPackDetailUseCaseInterface {
  public var packDetailHandler: @Sendable (String) async throws -> FestivalPackDetail?
  public var packChangesHandler: @Sendable (String, Int) async throws -> FestivalPackChanges
  public var updatePackHandler: @Sendable (String) async throws -> FestivalPackDetail?
  public var deletePackHandler: @Sendable (String) async throws -> Void
  public var checklistHandler: @Sendable (String) -> FestivalChecklist
  public var saveChecklistHandler: @Sendable (FestivalChecklist, String) -> Void
  public var autoDownloadHandler: @Sendable () -> Bool
  public var setAutoDownloadHandler: @Sendable (Bool) -> Void

  public init(
    packDetail: @escaping @Sendable (String) async throws -> FestivalPackDetail? = { _ in
      reportIssue("festivalPackDetailUseCase.packDetail 미등록")
      throw FestivalPackError.notRegistered
    },
    packChanges: @escaping @Sendable (String, Int) async throws -> FestivalPackChanges = { _, _ in
      reportIssue("festivalPackDetailUseCase.packChanges 미등록")
      throw FestivalPackError.notRegistered
    },
    updatePack: @escaping @Sendable (String) async throws -> FestivalPackDetail? = { _ in
      reportIssue("festivalPackDetailUseCase.updatePack 미등록")
      throw FestivalPackError.notRegistered
    },
    deletePack: @escaping @Sendable (String) async throws -> Void = { _ in
      reportIssue("festivalPackDetailUseCase.deletePack 미등록")
      throw FestivalPackError.notRegistered
    },
    checklist: @escaping @Sendable (String) -> FestivalChecklist = { _ in
      reportIssue("festivalPackDetailUseCase.checklist 미등록")
      return FestivalChecklist()
    },
    saveChecklist: @escaping @Sendable (FestivalChecklist, String) -> Void = { _, _ in
      reportIssue("festivalPackDetailUseCase.saveChecklist 미등록")
    },
    autoDownloadOnWiFi: @escaping @Sendable () -> Bool = {
      reportIssue("festivalPackDetailUseCase.autoDownloadOnWiFi 미등록")
      return false
    },
    setAutoDownloadOnWiFi: @escaping @Sendable (Bool) -> Void = { _ in
      reportIssue("festivalPackDetailUseCase.setAutoDownloadOnWiFi 미등록")
    }
  ) {
    packDetailHandler = packDetail
    packChangesHandler = packChanges
    updatePackHandler = updatePack
    deletePackHandler = deletePack
    checklistHandler = checklist
    saveChecklistHandler = saveChecklist
    autoDownloadHandler = autoDownloadOnWiFi
    setAutoDownloadHandler = setAutoDownloadOnWiFi
  }

  public func packDetail(festivalID: String) async throws -> FestivalPackDetail? {
    try await packDetailHandler(festivalID)
  }

  public func packChanges(festivalID: String, fromVersion: Int) async throws -> FestivalPackChanges {
    try await packChangesHandler(festivalID, fromVersion)
  }

  public func updatePack(festivalID: String) async throws -> FestivalPackDetail? {
    try await updatePackHandler(festivalID)
  }

  public func deletePack(festivalID: String) async throws {
    try await deletePackHandler(festivalID)
  }

  public func checklist(festivalID: String) -> FestivalChecklist {
    checklistHandler(festivalID)
  }

  public func saveChecklist(_ checklist: FestivalChecklist, festivalID: String) {
    saveChecklistHandler(checklist, festivalID)
  }

  public func autoDownloadOnWiFi() -> Bool {
    autoDownloadHandler()
  }

  public func setAutoDownloadOnWiFi(_ isOn: Bool) {
    setAutoDownloadHandler(isOn)
  }
}
