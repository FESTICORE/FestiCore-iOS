//
//  BearerRegisterFeatureTests.swift
//  BearerTests
//
//  Created by FestiCore on 11/12/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Bearer

@MainActor
@Suite("코드 없는 깃발 등록(S14 C·D·E)")
struct BearerRegisterFeatureTests {
  private static let now = Date(timeIntervalSince1970: 1_794_528_000) // 2026-11-13 00:00 UTC

  nonisolated private static let catalog = [
    FestivalCatalogItem(
      id: "fst_past",
      name: "지난 페스티벌",
      firstDate: "2026-10-01",
      lastDate: "2026-10-02",
      packVersion: 1
    ),
    FestivalCatalogItem(
      id: "fst_seoul",
      name: "서울 파크 뮤직 페스티벌",
      firstDate: "2026-12-19",
      lastDate: "2026-12-20",
      packVersion: 1
    ),
    FestivalCatalogItem(
      id: "fst_wonder",
      name: "원더리벳 2026",
      firstDate: "2026-11-20",
      lastDate: "2026-11-22",
      packVersion: 1
    ),
    FestivalCatalogItem(
      id: "fst_busan",
      name: "부산국제록페스티벌 2026",
      firstDate: "2026-11-30",
      lastDate: "2026-12-01",
      packVersion: 1
    ),
    FestivalCatalogItem(
      id: "fst_late",
      name: "늦은 페스티벌",
      firstDate: "2027-01-10",
      lastDate: nil,
      packVersion: 1
    ),
  ]

  private static let wonder = BearerFestivalOption(
    id: "fst_wonder",
    name: "원더리벳 2026",
    dateText: "11/20-22",
    hasPack: false
  )

  private static let change = BearerProfileChange(
    name: "호락호락",
    bio: "",
    tags: [.newbie],
    planVisible: true,
    homeZoneID: nil
  )

  @Test("받은 팩을 먼저, 끝나지 않은 서버 페스티벌을 시작 순으로 고를 수 있게 한다")
  func festivalOptions() {
    let options = BearerRegisterFeature.options(
      packs: [FestivalReceivedPack(
        id: "fst_busan",
        name: "부산국제록페스티벌 2026",
        packVersion: 3
      )],
      catalog: Self.catalog,
      today: "2026-11-12"
    )

    #expect(options.received == [BearerFestivalOption(
      id: "fst_busan",
      name: "부산국제록페스티벌 2026",
      dateText: "11/30-12/1",
      hasPack: true
    )])
    #expect(options.upcoming.map(\.id) == ["fst_wonder", "fst_seoul", "fst_late"])
    #expect(options.upcoming.first?.title == "원더리벳 2026 · 11/20-22")
    #expect(options.upcoming.last?.dateText == "1/10")
  }

  @Test("케이스 1: 받은 팩이 없으면 앞으로 열리는 페스티벌 3개를 보이고 라이브에서 연 페스티벌을 먼저 고른다")
  func loadsUpcomingAndSelectsPreferred() async {
    let store = makeStore(
      state: BearerRegisterFeature.State(preferredFestivalID: "fst_wonder"),
      packs: []
    )

    await store.send(.view(.onAppear))
    await store.receive(\.async.loadFestivals)
    await store.receive(\.inner.festivalsLoaded) {
      $0.festivals.load = .loaded
      $0.festivals.upcoming = BearerRegisterFeature.options(
        packs: [],
        catalog: Self.catalog,
        today: "2026-11-12"
      ).upcoming
      $0.selectedFestivalID = "fst_wonder"
    }
    #expect(store.state.festivals.visibleUpcoming.map(\.id) == ["fst_wonder", "fst_busan", "fst_seoul"])
    #expect(store.state.festivals.canShowMore)

    await store.send(.view(.showMoreTapped)) { $0.festivals.showsAllUpcoming = true }
    #expect(store.state.festivals.visibleUpcoming.count == 4)
    #expect(!store.state.festivals.canShowMore)
  }

  @Test("케이스 2: 받은 팩이 있으면 그 팩을 고르고 팩의 존을 읽는다")
  func receivedPackLoadsZones() async {
    let store = makeStore(
      state: BearerRegisterFeature.State(),
      packs: [FestivalReceivedPack(
        id: "fst_wonder",
        name: "원더리벳 2026",
        packVersion: 2
      )],
      useCase: BearerUseCaseStub(fetchFestival: { festivalID in
        #expect(festivalID == "fst_wonder")
        return BearerFestival(
          id: festivalID,
          name: "원더리벳 2026",
          zones: [BearerZone(
            id: "zone_a",
            name: "리벳 스테이지 앞 왼쪽"
          )]
        )
      })
    )
    store.exhaustivity = .off

    await store.send(.view(.onAppear))
    await store.receive(\.inner.festivalsLoaded)
    #expect(store.state.selectedFestivalID == "fst_wonder")
    #expect(store.state.selectedFestival?.hasPack == true)
    await store.receive(\.inner.zonesLoaded) {
      $0.zones = [BearerZone(
        id: "zone_a",
        name: "리벳 스테이지 앞 왼쪽"
      )]
    }
  }

  @Test("고를 페스티벌이 없으면 실패로 두고 다시 시도할 수 있다")
  func emptyFestivalsFail() async {
    let store = TestStore(initialState: BearerRegisterFeature.State()) {
      BearerRegisterFeature()
    } withDependencies: {
      $0.date.now = Self.now
      $0.calendar = Calendar(identifier: .gregorian)
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(receivedPacks: { [] })
      $0.festivalCatalogUseCase = MockFestivalCatalogUseCase(
        cachedFestivals: { [] },
        refreshFestivals: { throw URLError(.notConnectedToInternet) }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.loadFestivals)
    await store.receive(\.inner.festivalsFailed) {
      $0.festivals.load = .failed(offline: true)
    }
    await store.send(.view(.retryTapped)) { $0.festivals.load = .loading }
    await store.receive(\.async.loadFestivals)
    await store.receive(\.inner.festivalsFailed) {
      $0.festivals.load = .failed(offline: true)
    }
  }

  @Test("등록하면 태그가 없을 때 초보 환영으로 보내고, 성공하면 핀을 요청하고 저장 완료(E1)를 보인다")
  func registerSucceeds() async {
    let request = BearerRegisterRequest(
      festivalID: "fst_wonder",
      change: Self.change,
      idempotencyKey: "register-1"
    )
    let claim = BearerClaim(
      flagID: "flg_9",
      profile: BearerFlagProfile(
        id: "flg_9",
        name: "호락호락",
        tags: [.newbie]
      ),
      isNew: true,
      coBearerIDs: []
    )
    var state = loadedState()
    state.form.name = "호락호락"
    let store = TestStore(initialState: state) {
      BearerRegisterFeature()
    } withDependencies: {
      $0.bearerUseCase = BearerUseCaseStub(
        makeRegisterRequestHandler: { festivalID, change in
          #expect(festivalID == "fst_wonder")
          #expect(change == Self.change)
          return request
        },
        registerHandler: { sent in
          #expect(sent == request)
          return claim
        }
      )
    }

    await store.send(.view(.saveTapped)) {
      $0.pendingRequest = request
      $0.isSaving = true
    }
    await store.receive(\.async.register)
    await store.receive(\.inner.registered) {
      $0.isSaving = false
      $0.pendingRequest = nil
      $0.completion = BearerRegisterFeature.Completion(
        claim: claim,
        festival: Self.wonder
      )
    }
    await store.receive(\.delegate.registered)

    await store.send(.view(.primaryDoneTapped))
    await store.receive(\.delegate.packRequested)
    await store.send(.view(.secondaryDoneTapped))
    await store.receive(\.delegate.finished)
  }

  @Test("오프라인이면 같은 멱등키를 남겨 다시 누를 때 같은 등록으로 보낸다")
  func offlineRetryReusesKey() async {
    let request = BearerRegisterRequest(
      festivalID: "fst_wonder",
      change: Self.change,
      idempotencyKey: "register-1"
    )
    let made = LockIsolated(0)
    var state = loadedState()
    state.form.name = "호락호락"
    let store = TestStore(initialState: state) {
      BearerRegisterFeature()
    } withDependencies: {
      $0.bearerUseCase = BearerUseCaseStub(
        makeRegisterRequestHandler: { _, _ in
          made.withValue { $0 += 1 }
          return request
        },
        registerHandler: { _ in throw BearerError.offline }
      )
    }

    await store.send(.view(.saveTapped)) {
      $0.pendingRequest = request
      $0.isSaving = true
    }
    await store.receive(\.async.register)
    await store.receive(\.inner.registerFailed) {
      $0.isSaving = false
      $0.saveError = "인터넷에 연결되지 않았어요. 연결 후 다시 눌러 주세요"
    }
    await store.send(.view(.saveTapped)) {
      $0.isSaving = true
      $0.saveError = nil
    }
    await store.receive(\.async.register)
    await store.receive(\.inner.registerFailed) {
      $0.isSaving = false
      $0.saveError = "인터넷에 연결되지 않았어요. 연결 후 다시 눌러 주세요"
    }
    #expect(made.value == 1)
  }

  @Test("409 이름 중복·기수 한도는 팝업으로 안내한다")
  func conflictsShowAlerts() async {
    var state = loadedState()
    state.form.name = "호락호락"
    state.pendingRequest = BearerRegisterRequest(
      festivalID: "fst_wonder",
      change: Self.change,
      idempotencyKey: "register-1"
    )
    let store = TestStore(initialState: state) { BearerRegisterFeature() }

    await store.send(.inner(.registerFailed(.nameTaken))) {
      $0.nameError = "이미 있는 깃발 이름이에요. 다른 이름을 지어 주세요."
      $0.destination = .alert(.bearerNameTaken())
      $0.pendingRequest = nil
    }
    #expect(!store.state.canSave)
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
    }
    await store.send(.inner(.registerFailed(.bearerLimit))) {
      $0.destination = .alert(.bearerLimit(festivalName: "원더리벳 2026"))
    }
  }

  @Test("이름이 2자 미만이거나 페스티벌을 고르지 않으면 등록할 수 없다")
  func validation() {
    var state = loadedState()
    state.form.name = "호"
    #expect(!state.canSave)
    state.form.name = "호락"
    #expect(state.canSave)
    state.selectedFestivalID = nil
    #expect(!state.canSave)
  }

  @Test("기수 여부는 고른 뒤 다음을 눌러야 넘어간다")
  func roleChoice() async {
    let store = TestStore(initialState: BearerRoleChoiceFeature.State()) { BearerRoleChoiceFeature() }

    await store.send(.view(.nextTapped))
    await store.send(.view(.roleTapped(.bearer))) { $0.role = .bearer }
    await store.send(.view(.nextTapped))
    await store.receive(\.delegate.bearerChosen)
    await store.send(.view(.roleTapped(.audience))) { $0.role = .audience }
    await store.send(.view(.nextTapped))
    await store.receive(\.delegate.audienceChosen)
  }

  private func loadedState() -> BearerRegisterFeature.State {
    var state = BearerRegisterFeature.State()
    state.festivals.load = .loaded
    state.festivals.upcoming = [Self.wonder]
    state.selectedFestivalID = "fst_wonder"
    return state
  }

  private func makeStore(
    state: BearerRegisterFeature.State,
    packs: [FestivalReceivedPack],
    useCase: BearerUseCaseStub = BearerUseCaseStub()
  ) -> TestStoreOf<BearerRegisterFeature> {
    return TestStore(initialState: state) {
      BearerRegisterFeature()
    } withDependencies: {
      $0.date.now = Self.now
      $0.calendar = Calendar(identifier: .gregorian)
      $0.bearerUseCase = useCase
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(receivedPacks: { packs })
      $0.festivalCatalogUseCase = MockFestivalCatalogUseCase(refreshFestivals: { Self.catalog })
    }
  }
}
