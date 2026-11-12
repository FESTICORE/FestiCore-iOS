//
//  PackDetailFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestiCoreLocationInterface
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import Testing
@testable import Profile

@MainActor
struct PackDetailFeatureTests {
  @Test("막차·셔틀 시각은 기기 설정과 관계없이 서울 시간대의 24시간 HH:mm으로 보인다")
  func lastRideTimeUsesSeoul24Hour() {
    #expect(PackDetailView.timeText("2026-11-22T22:20:00+09:00") == "22:20")
    #expect(PackDetailView.timeText("2026-11-22T13:52:00Z") == "22:52")
    #expect(PackDetailView.timeText("2026-11-23T00:10:00+09:00") == "00:10")
    #expect(PackDetailView.timeText("23:40") == "23:40")
    #expect(PackDetailView.timeText(nil) == "-")
  }

  @Test func appearLoadsPackChecklistAndChangesForOutdatedPack() async {
    let detail = sampleDetail(version: 12, latest: 13)
    let changes = FestivalPackChanges(fromVersion: 12, toVersion: 13, sizeBytes: 524_288, changedSets: 2)
    let store = TestStore(initialState: PackDetailFeature.State(festivalID: "fst_a", title: "팩")) {
      PackDetailFeature()
    } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(
        packDetail: { _ in detail },
        packChanges: { id, from in
          #expect(id == "fst_a")
          #expect(from == 12)
          return changes
        },
        checklist: { _ in FestivalChecklist(checkedIDs: ["ticket"]) },
        autoDownloadOnWiFi: { false }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.detail = detail
      $0.title = "원더리벳 2026"
      $0.load = .loaded
      $0.checklist = FestivalChecklist(checkedIDs: ["ticket"])
      $0.autoDownloadOnWiFi = false
    }
    await store.receive(\.async.fetchChanges)
    await store.receive(\.inner.changesLoaded) { $0.changes = changes }
    #expect(store.state.checkedCount == 1)
    #expect(store.state.checklistRows.map(\.id) == ["ticket", "earplug"])
  }

  @Test func missingPackAndFailureAreShownSeparately() async {
    let attempts = LockIsolated(0)
    let store = TestStore(initialState: PackDetailFeature.State(festivalID: "fst_a", title: "팩")) {
      PackDetailFeature()
    } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(
        packDetail: { _ in
          attempts.withValue { $0 += 1 }
          if attempts.value == 1 { throw URLError(.cannotOpenFile) }
          return nil
        },
        checklist: { _ in FestivalChecklist() },
        autoDownloadOnWiFi: { true }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.receive(\.inner.loadFailed) { $0.load = .failed }
    await store.send(.view(.retryTapped)) { $0.load = .loading }
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) { $0.load = .missing }
  }

  @Test func checklistEditsAreSavedAndRequiredItemsStay() async {
    let saved = LockIsolated<[FestivalChecklist]>([])
    var state = PackDetailFeature.State(festivalID: "fst_a", title: "원더리벳 2026")
    state.detail = sampleDetail(version: 12, latest: 12)
    state.load = .loaded
    let store = TestStore(initialState: state) {
      PackDetailFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(
        saveChecklist: { checklist, _ in saved.withValue { $0.append(checklist) } }
      )
    }

    await store.send(.view(.itemToggled("earplug"))) { $0.checklist.checkedIDs = ["earplug"] }
    await store.send(.view(.editTapped)) { $0.isEditingChecklist = true }
    await store.send(.binding(.set(\.newItemText, "  선크림 "))) { $0.newItemText = "  선크림 " }
    await store.send(.view(.addItemTapped)) {
      $0.checklist.customItems = [.init(id: "custom-00000000-0000-0000-0000-000000000000", label: "선크림")]
      $0.newItemText = ""
    }
    // 필수 항목은 지우지 않는다.
    await store.send(.view(.itemRemoved("ticket")))
    await store.send(.view(.itemRemoved("earplug"))) {
      $0.checklist.hiddenIDs = ["earplug"]
      $0.checklist.checkedIDs = []
    }
    await store.send(.view(.itemRemoved("custom-00000000-0000-0000-0000-000000000000"))) {
      $0.checklist.customItems = []
    }
    await store.send(.view(.editDoneTapped)) { $0.isEditingChecklist = false }
    #expect(store.state.checklistRows.map(\.id) == ["ticket"])
    await store.finish()
    #expect(saved.value.count == 4)
    #expect(saved.value.last == FestivalChecklist(hiddenIDs: ["earplug"]))
  }

  @Test func updateReplacesPackAndAsksProfileToReload() async {
    var state = PackDetailFeature.State(festivalID: "fst_a", title: "원더리벳 2026")
    state.detail = sampleDetail(version: 12, latest: 13)
    state.load = .loaded
    state.changes = FestivalPackChanges(fromVersion: 12, toVersion: 13, sizeBytes: 1, changedSets: 1)
    let updated = sampleDetail(version: 13, latest: 13)
    let store = TestStore(initialState: state) {
      PackDetailFeature()
    } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(updatePack: { _ in updated })
    }

    await store.send(.view(.updateTapped)) { $0.isUpdating = true }
    await store.receive(\.async.update)
    await store.receive(\.inner.updateFinished) {
      $0.isUpdating = false
      $0.detail = updated
      $0.changes = nil
      $0.manageMessage = "새 버전 v13을 받았어요"
    }
    await store.receive(\.delegate.packChanged)
  }

  @Test func updateTapWhileUpdatingIsIgnored() async {
    var state = PackDetailFeature.State(festivalID: "fst_a", title: "원더리벳 2026")
    state.detail = sampleDetail(version: 12, latest: 13)
    state.load = .loaded
    state.isUpdating = true
    let store = TestStore(initialState: state) { PackDetailFeature() }

    // 받는 중에 다시 눌러도 한 번만 받는다.
    await store.send(.view(.updateTapped))
    await store.send(.view(.checkUpdateTapped))
  }

  @Test(arguments: [
    (FestivalPackError.retryLater as any Error, PackDetailFeature.UpdateFailure.retryLater,
     "지금은 받는 사람이 많아요. 잠시 후 다시 시도해 주세요."),
    (FestivalPackError.offline, .offline,
     "인터넷에 연결되어 있지 않아요. 연결을 확인한 뒤 다시 시도해 주세요."),
    (FestivalPackError.invalidResponse, .other, "업데이트를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.")
  ])
  func updateFailureKeepsPackAndShowsReason(
    error: any Error, failure: PackDetailFeature.UpdateFailure, message: String
  ) async {
    var state = PackDetailFeature.State(festivalID: "fst_a", title: "원더리벳 2026")
    state.detail = sampleDetail(version: 12, latest: 12)
    state.load = .loaded
    let store = TestStore(initialState: state) {
      PackDetailFeature()
    } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(
        updatePack: { _ in throw error }
      )
    }

    await store.send(.view(.checkUpdateTapped)) { $0.isUpdating = true }
    await store.receive(\.async.update)
    await store.receive(\.inner.updateFailed, failure) {
      $0.isUpdating = false
      $0.manageMessage = message
    }
  }

  @Test func updateAndDeleteDoNotStartWhileTheOtherRuns() async {
    var state = PackDetailFeature.State(festivalID: "fst_a", title: "원더리벳 2026")
    state.detail = sampleDetail(version: 12, latest: 13)
    state.load = .loaded
    state.isUpdating = true
    let updating = TestStore(initialState: state) { PackDetailFeature() }
    await updating.send(.view(.deleteTapped))

    state.isUpdating = false
    state.isDeleting = true
    let deleting = TestStore(initialState: state) { PackDetailFeature() }
    await deleting.send(.view(.updateTapped))
    await deleting.send(.view(.checkUpdateTapped))
  }

  @Test func confirmingDeleteCancelsInFlightUpdate() async {
    let deleted = LockIsolated<[String]>([])
    var state = PackDetailFeature.State(festivalID: "fst_a", title: "원더리벳 2026")
    state.detail = sampleDetail(version: 12, latest: 13)
    state.load = .loaded
    state.destination = .alert(.deletePack(name: "원더리벳 2026"))
    let store = TestStore(initialState: state) {
      PackDetailFeature()
    } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(
        updatePack: { _ in
          try await Task.sleep(nanoseconds: 60_000_000_000)
          return nil
        },
        deletePack: { id in deleted.withValue { $0.append(id) } }
      )
    }

    await store.send(.view(.updateTapped)) { $0.isUpdating = true }
    await store.receive(\.async.update)
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
      $0.isDeleting = true
      $0.isUpdating = false
    }
    await store.receive(\.async.delete)
    await store.receive(\.inner.deleteFinished) { $0.isDeleting = false }
    await store.receive(\.delegate.packDeleted)
    #expect(deleted.value == ["fst_a"])
  }

  @Test func deleteRequiresConfirmation() async {
    let deleted = LockIsolated<[String]>([])
    var state = PackDetailFeature.State(festivalID: "fst_a", title: "원더리벳 2026")
    state.detail = sampleDetail(version: 12, latest: 12)
    state.load = .loaded
    let store = TestStore(initialState: state) {
      PackDetailFeature()
    } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(
        deletePack: { id in deleted.withValue { $0.append(id) } }
      )
    }

    await store.send(.view(.deleteTapped)) {
      $0.destination = .alert(.deletePack(name: "원더리벳 2026"))
    }
    await store.send(.destination(.presented(.alert(.cancelTapped)))) { $0.destination = nil }
    #expect(deleted.value.isEmpty)

    await store.send(.view(.deleteTapped)) {
      $0.destination = .alert(.deletePack(name: "원더리벳 2026"))
    }
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
      $0.isDeleting = true
    }
    await store.receive(\.async.delete)
    await store.receive(\.inner.deleteFinished) { $0.isDeleting = false }
    await store.receive(\.delegate.packDeleted)
    #expect(deleted.value == ["fst_a"])
  }

  @Test("탭 바 칸 번호와 본문 페이지 번호는 같은 탭을 가리키고, 범위 밖이면 가는 길로 둔다")
  func tabBarIndexAndPageIndexShareTab() {
    #expect(PackDetailFeature.Tab.allCases.map(\.rawValue) == [0, 1, 2])
    #expect(PackDetailView.tab(at: 0) == .directions)
    #expect(PackDetailView.tab(at: 1) == .checklist)
    #expect(PackDetailView.tab(at: 2) == .manage)
    #expect(PackDetailView.tab(at: 3) == .directions)
  }

  @Test("탭 바를 누르면 선택 탭 상태가 바뀐다")
  func tabTapChangesSelectedTab() async {
    var state = PackDetailFeature.State(
      festivalID: "fst_a",
      title: "팩"
    )
    state.detail = sampleDetail(
      version: 12,
      latest: 12
    )
    state.load = .loaded
    let store = TestStore(initialState: state) {
      PackDetailFeature()
    }

    await store.send(.view(.tabSelected(.manage))) { $0.tab = .manage }
    await store.send(.view(.tabSelected(.directions))) { $0.tab = .directions }
  }

  @Test("본문을 좌우로 넘기면 페이지 번호대로 같은 선택 탭이 바뀌고, 준비물 페이지를 벗어나면 편집을 끝낸다")
  func swipeChangesSameSelectedTab() async {
    var state = PackDetailFeature.State(
      festivalID: "fst_a",
      title: "팩"
    )
    state.detail = sampleDetail(
      version: 12,
      latest: 12
    )
    state.load = .loaded
    state.tab = .checklist
    state.isEditingChecklist = true
    let store = TestStore(initialState: state) {
      PackDetailFeature()
    }

    // 준비물(1) → 팩 관리(2) → 준비물(1) → 가는 길(0)
    await store.send(.view(.tabSelected(PackDetailView.tab(at: 2)))) {
      $0.tab = .manage
      $0.isEditingChecklist = false
    }
    await store.send(.view(.tabSelected(PackDetailView.tab(at: 1)))) { $0.tab = .checklist }
    await store.send(.view(.tabSelected(PackDetailView.tab(at: 0)))) { $0.tab = .directions }
  }

  @Test func autoDownloadToggleIsStored() async {
    let stored = LockIsolated<Bool?>(nil)
    let store = TestStore(initialState: PackDetailFeature.State(festivalID: "fst_a", title: "팩")) {
      PackDetailFeature()
    } withDependencies: {
      $0.festivalPackDetailUseCase = MockFestivalPackDetailUseCase(
        setAutoDownloadOnWiFi: { stored.setValue($0) }
      )
    }

    await store.send(.view(.autoDownloadToggled(false))) { $0.autoDownloadOnWiFi = false }
    await store.finish()
    #expect(stored.value == false)
  }

  /// Figma S11 G: 가는 길 탭이 보이면 지도 앱 설치 여부를 확인해 없는 앱을 웹 버튼으로 바꾼다.
  @Test func directionsChecksInstalledMapApps() async {
    let initial = PackDetailFeature.State(
      festivalID: "fst_a",
      title: "팩"
    )
    let store = TestStore(initialState: initial) {
      PackDetailFeature()
    } withDependencies: {
      $0.mapAppClient = MockMapAppClient { app in
        return app == .naver
      }
    }

    await store.send(.view(.directionsAppeared))
    await store.receive(\.async.checkMapApps)
    await store.receive(\.inner.mapAppsChecked) { $0.installedMapApps = [.naver] }
  }

  private func sampleDetail(version: Int, latest: Int) -> FestivalPackDetail {
    FestivalPackDetail(
      pack: FestivalReceivedPack(id: "fst_a", name: "원더리벳 2026", packVersion: version, latestPackVersion: latest),
      directions: .init(lastShuttleAt: "23:40", lastTrainAt: "23:52"),
      checklist: [
        .init(id: "ticket", label: "모바일 티켓", required: true),
        .init(id: "earplug", label: "귀마개")
      ],
      rules: ["유리병"]
    )
  }
}
