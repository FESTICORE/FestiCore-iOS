//
//  BearerFestivalTransferFeatureTests.swift
//  BearerTests
//
//  Created by FestiCore on 11/26/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestivalDomainInterface
import FestiCoreSharedUI
import Foundation
import Testing
@testable import Bearer

@MainActor
@Suite("깃발 축제 이동(S10 깃발 상세 메뉴)")
struct BearerFestivalTransferFeatureTests {
  private static let now = Date(timeIntervalSince1970: 1_794_528_000) // 2026-11-13 00:00 UTC

  private nonisolated static let catalog = [
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
  ]

  private static let request = BearerFestivalTransferRequest(
    flagID: "flg_1",
    fromFestivalID: "fst_wonder",
    toFestivalID: "fst_busan",
    idempotencyKey: "transfer-1"
  )

  private static let transfer = BearerFestivalTransfer(
    flagID: "flg_1",
    previousFestivalID: "fst_wonder",
    festivalID: "fst_busan",
    profile: BearerFlagProfile(
      id: "flg_1",
      name: "호락호락"
    )
  )

  @Test("지금 페스티벌을 뺀 후보를 보이고 아무것도 미리 고르지 않는다")
  func loadsOtherFestivals() async {
    let store = makeStore()

    await store.send(.view(.onAppear))
    await store.receive(\.async.loadFestivals)
    await store.receive(\.inner.festivalsLoaded) {
      $0.festivals.load = .loaded
      $0.festivals.upcoming = [BearerFestivalOption(
        id: "fst_busan",
        name: "부산국제록페스티벌 2026",
        dateText: "11/30-12/1",
        hasPack: false
      )]
    }
    #expect(store.state.selectedFestivalID == nil)
    #expect(!store.state.canTransfer)
  }

  @Test("옮기기를 누르면 초기화 안내 팝업을 띄우고, 확인하면 이동해 부모에 새 페스티벌을 알린다")
  func confirmThenTransfer() async {
    let sent = LockIsolated<[BearerFestivalTransferRequest]>([])
    let store = makeStore(useCase: BearerUseCaseStub(
      makeFestivalTransferRequestHandler: { flagID, fromFestivalID, toFestivalID in
        #expect(flagID == "flg_1")
        #expect(fromFestivalID == "fst_wonder")
        #expect(toFestivalID == "fst_busan")
        return Self.request
      },
      transferFestivalHandler: { request in
        sent.withValue { $0.append(request) }
        return Self.transfer
      }
    ))
    store.exhaustivity = .off

    await store.send(.view(.onAppear))
    await store.receive(\.inner.festivalsLoaded)
    await store.send(.view(.festivalTapped("fst_busan"))) { $0.selectedFestivalID = "fst_busan" }
    #expect(store.state.canTransfer)

    await store.send(.view(.transferTapped)) {
      $0.destination = .confirm(.bearerFestivalTransfer(festivalName: "부산국제록페스티벌 2026"))
    }
    await store.send(.destination(.presented(.confirm(.confirmTapped)))) {
      $0.destination = nil
      $0.isSaving = true
      $0.pendingRequest = Self.request
    }
    await store.receive(\.inner.transferred) {
      $0.isSaving = false
      $0.pendingRequest = nil
    }
    await store.receive(\.delegate.transferred)
    #expect(sent.value == [Self.request])
  }

  @Test("팝업에서 취소하면 보내지 않는다")
  func cancelDoesNotSend() async {
    let store = makeStore()
    store.exhaustivity = .off

    await store.send(.view(.onAppear))
    await store.receive(\.inner.festivalsLoaded)
    await store.send(.view(.festivalTapped("fst_busan")))
    await store.send(.view(.transferTapped))
    await store.send(.destination(.presented(.confirm(.cancelTapped)))) {
      $0.destination = nil
    }
    #expect(!store.state.isSaving)
  }

  @Test("연결이 끊겨 실패하면 같은 멱등키로 다시 보낸다")
  func offlineRetryReusesKey() async {
    let made = LockIsolated(0)
    let sent = LockIsolated<[String]>([])
    let store = makeStore(useCase: BearerUseCaseStub(
      makeFestivalTransferRequestHandler: { _, _, _ in
        made.withValue { $0 += 1 }
        return Self.request
      },
      transferFestivalHandler: { request in
        sent.withValue { $0.append(request.idempotencyKey) }
        if sent.value.count == 1 { throw BearerError.offline }
        return Self.transfer
      }
    ))
    store.exhaustivity = .off

    await store.send(.view(.onAppear))
    await store.receive(\.inner.festivalsLoaded)
    await store.send(.view(.festivalTapped("fst_busan")))
    await store.send(.view(.transferTapped))
    await store.send(.destination(.presented(.confirm(.confirmTapped))))
    await store.receive(\.inner.transferFailed) {
      $0.isSaving = false
      $0.errorMessage = "인터넷에 연결되지 않았어요. 연결 후 다시 눌러 주세요"
    }
    #expect(store.state.pendingRequest == Self.request)

    await store.send(.view(.transferTapped))
    await store.send(.destination(.presented(.confirm(.confirmTapped))))
    await store.receive(\.inner.transferred)
    #expect(made.value == 1)
    #expect(sent.value == ["transfer-1", "transfer-1"])
  }

  @Test(
    "서버 거절은 코드별 안내를 보이고 다음 시도는 새 멱등키를 쓴다",
    arguments: [
      (BearerError.festivalMismatch, "이미 다른 페스티벌로 옮겨진 깃발이에요. 깃발 상세를 다시 열어 확인해 주세요"),
      (.hasCoBearers, "공동 기수가 있는 깃발은 옮길 수 없어요"),
      (.bearerLimit, "옮길 페스티벌에 이미 내 깃발이 있어요. 페스티벌마다 깃발은 하나만 맡을 수 있어요"),
      (.nameTaken, "옮길 페스티벌에 같은 이름의 깃발이 있어요. 이름을 바꾼 뒤 다시 옮겨 주세요"),
      (.bearerModeOff, "기수 모드가 꺼져 있어요. 마이에서 기수 모드를 켠 뒤 다시 옮겨 주세요"),
      (.notOwner, "처음 깃발을 만든 기수만 옮길 수 있어요"),
      (.notBearer, "이 깃발의 기수가 아니에요"),
      (.termsRequired, "새 약관에 동의한 뒤에 옮겨 주세요"),
      (.notFound, "깃발이나 페스티벌을 찾지 못했어요"),
      (.conflict, "이미 처리 중인 요청이에요. 잠시 후 다시 시도해 주세요"),
    ]
  )
  func rejectionMessages(
    error: BearerError,
    message: String
  ) async {
    let store = makeStore(useCase: BearerUseCaseStub(
      makeFestivalTransferRequestHandler: { _, _, _ in Self.request },
      transferFestivalHandler: { _ in throw error }
    ))
    store.exhaustivity = .off

    await store.send(.view(.onAppear))
    await store.receive(\.inner.festivalsLoaded)
    await store.send(.view(.festivalTapped("fst_busan")))
    await store.send(.view(.transferTapped))
    await store.send(.destination(.presented(.confirm(.confirmTapped))))
    await store.receive(\.inner.transferFailed) {
      $0.isSaving = false
      $0.errorMessage = message
      $0.pendingRequest = nil
    }
  }

  @Test("다른 페스티벌을 고르면 안내를 지운다")
  func selectingClearsError() async {
    var state = BearerFestivalTransferFeature.State(
      flagID: "flg_1",
      fromFestivalID: "fst_wonder"
    )
    state.errorMessage = "x"
    let store = TestStore(initialState: state) {
      BearerFestivalTransferFeature()
    }

    await store.send(.view(.festivalTapped("fst_busan"))) {
      $0.selectedFestivalID = "fst_busan"
      $0.errorMessage = nil
    }
    await store.send(.view(.backTapped))
    await store.receive(\.delegate.backRequested)
  }

  private func makeStore(useCase: BearerUseCaseStub = BearerUseCaseStub()) -> TestStoreOf<BearerFestivalTransferFeature> {
    return TestStore(initialState: BearerFestivalTransferFeature.State(
      flagID: "flg_1",
      fromFestivalID: "fst_wonder"
    )) {
      BearerFestivalTransferFeature()
    } withDependencies: {
      $0.date.now = Self.now
      $0.calendar = Calendar(identifier: .gregorian)
      $0.bearerUseCase = useCase
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(receivedPacks: { [] })
      $0.festivalCatalogUseCase = MockFestivalCatalogUseCase(refreshFestivals: { Self.catalog })
    }
  }
}
