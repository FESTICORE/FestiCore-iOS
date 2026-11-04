//
//  FestivalPackDetailUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 팩 상세 화면의 가는 길·준비물·팩 관리 작업
public protocol FestivalPackDetailUseCaseInterface: Sendable {
  /// 기기에 받은 팩. 팩이 없으면 nil이다. 네트워크에 연결하지 않는다.
  func packDetail(festivalID: String) async throws -> FestivalPackDetail?
  /// 받은 버전과 현재 발행 팩의 차이
  func packChanges(festivalID: String, fromVersion: Int) async throws -> FestivalPackChanges
  /// 서버와 버전을 맞추고 바뀐 팩을 돌려준다.
  func updatePack(festivalID: String) async throws -> FestivalPackDetail?
  /// 기기에서 팩을 지운다. 내 준비물은 남긴다.
  func deletePack(festivalID: String) async throws
  /// 축제별 준비물 목록을 기기에서 읽는다.
  func checklist(festivalID: String) -> FestivalChecklist
  /// 축제별 준비물 목록을 기기에 저장한다.
  func saveChecklist(_ checklist: FestivalChecklist, festivalID: String)
  /// 와이파이 자동 갱신 설정을 읽는다.
  func autoDownloadOnWiFi() -> Bool
  /// 와이파이 자동 갱신 설정을 저장한다.
  func setAutoDownloadOnWiFi(_ isOn: Bool)
}

public enum FestivalPackDetailUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalPackDetailUseCaseInterface { MockFestivalPackDetailUseCase() }
  public static var previewValue: any FestivalPackDetailUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalPackDetailUseCase: any FestivalPackDetailUseCaseInterface {
    get { self[FestivalPackDetailUseCaseDependency.self] }
    set { self[FestivalPackDetailUseCaseDependency.self] = newValue }
  }
}
