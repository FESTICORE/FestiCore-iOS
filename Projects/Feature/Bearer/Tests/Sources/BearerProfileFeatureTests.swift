//
//  BearerProfileFeatureTests.swift
//  BearerTests
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import Foundation
import Testing
@testable import Bearer

@MainActor
struct BearerProfileFeatureTests {
  private func newState() -> BearerProfileFeature.State {
    BearerProfileFeature.State(festivalID: "fst_1", flagID: "flg_1", profile: BearerSample.profile, isNewBearer: true)
  }

  @Test("코드 등록 직후에는 서버 임시 이름과 기본 태그를 비워 둔다")
  func placeholderCleared() {
    let state = newState()
    #expect(state.name.isEmpty)
    #expect(state.tags.isEmpty)
    #expect(!state.isLoading)
    #expect(!state.canSave)
  }

  @Test("오늘 계획은 프로필의 고른 공연을 들고 누르면 부모에게 내 일정을 요청한다")
  func planOpensMySchedule() async {
    let profile = BearerFlagProfile(
      id: "flg_1",
      name: "호락호락",
      plan: [
        "set_1",
        "set_2"
      ]
    )
    let store = TestStore(initialState: BearerProfileFeature.State(
      festivalID: "fst_1",
      flagID: "flg_1",
      profile: profile
    )) {
      BearerProfileFeature()
    }
    #expect(store.state.plan == [
      "set_1",
      "set_2"
    ])

    await store.send(.view(.planTapped))
    await store.receive(.delegate(.planRequested(festivalID: "fst_1")))
  }

  @Test("팩의 존·축제 이름과 기수 수를 채운다")
  func loads() async {
    let festival = BearerFestival(id: "fst_1", name: "원더리벳 2026", zones: [BearerZone(id: "zone_a", name: "리벳 스테이지 앞 왼쪽")])
    let board = BearerBoard(
      profile: BearerSample.profile,
      status: BearerFlagStatus(flagID: "flg_1", lifecycle: .scheduled, zoneID: nil, activity: nil, updatedAt: Date(timeIntervalSince1970: 0)),
      followerCount: 0,
      coBearers: [BearerCoBearer(userID: "usr_1", nickname: "로이"), BearerCoBearer(userID: "usr_2", nickname: "민지")]
    )
    let store = TestStore(initialState: newState()) {
      BearerProfileFeature()
    } withDependencies: {
      $0.bearerUseCase = BearerUseCaseStub(
        fetchFestival: { _ in festival },
        fetchBoard: { _ in board }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.load)
    await store.receive(\.inner.loaded) {
      $0.festivalName = "원더리벳 2026"
      $0.zones = festival.zones
      $0.bearerCount = 2
    }
  }

  @Test("소개는 서버처럼 코드포인트 60개까지 받는다")
  func bioCountsScalars() async {
    let store = TestStore(initialState: newState()) { BearerProfileFeature() }
    let flag = "🏳️‍🌈"
    let text = String(repeating: flag, count: 20)

    await store.send(.view(.bioChanged(text))) {
      $0.bio = BearerProfileFeature.prefix(text, scalars: 60)
    }
    #expect(store.state.bio.unicodeScalars.count == 60)
    #expect(store.state.bio.count < 20)
  }

  @Test("태그는 3개까지 고르고 다시 누르면 뺀다")
  func tags() async {
    let store = TestStore(initialState: newState()) { BearerProfileFeature() }

    await store.send(.view(.tagTapped(.slam))) { $0.tags = [.slam] }
    await store.send(.view(.tagTapped(.sing))) { $0.tags = [.slam, .sing] }
    await store.send(.view(.tagTapped(.newbie))) { $0.tags = [.slam, .sing, .newbie] }
    await store.send(.view(.tagTapped(.calm)))
    await store.send(.view(.tagTapped(.sing))) { $0.tags = [.slam, .newbie] }
  }

  @Test("저장하면 완료 화면으로 바뀌고 이름 중복이면 이름 칸에 오류를 보인다")
  func save() async {
    let saved = BearerFlagProfile(id: "flg_1", name: "호락호락", tags: [.slam])
    var state = newState()
    state.name = " 호락호락 "
    state.tags = [.slam]
    state.homeZoneID = "zone_a"
    let store = TestStore(initialState: state) {
      BearerProfileFeature()
    } withDependencies: {
      $0.bearerUseCase = BearerUseCaseStub(updateProfile: { flagID, change in
        #expect(flagID == "flg_1")
        #expect(change == BearerProfileChange(name: "호락호락", bio: "", tags: [.slam], planVisible: true, homeZoneID: "zone_a"))
        return saved
      })
    }

    await store.send(.view(.saveTapped)) { $0.isSaving = true }
    await store.receive(\.async.save)
    await store.receive(\.inner.saved) {
      $0.isSaving = false
      $0.savedProfile = saved
    }
    await store.send(.view(.doneTapped))
    await store.receive(.delegate(.finished(flagID: "flg_1")))
  }

  @Test("이름이 겹치면 이름 칸에 오류를 보이고 고치면 지운다")
  func nameTaken() async {
    var state = newState()
    state.name = "호락호락"
    state.tags = [.slam]
    let store = TestStore(initialState: state) { BearerProfileFeature() }

    await store.send(.inner(.saveFailed(.nameTaken))) {
      $0.nameError = "이미 있는 깃발 이름이에요. 다른 이름을 지어 주세요."
    }
    #expect(!store.state.canSave)
    await store.send(.view(.nameChanged("호락호락2"))) {
      $0.name = "호락호락2"
      $0.nameError = nil
    }
  }

  @Test("사진은 고르는 즉시 올리며 진행률을 보이고 끝나면 채운다")
  func uploadsPhoto() async {
    let data = Data([1, 2, 3])
    let photo = BearerFlagPhoto(photoURL: URL(string: "https://festicore.test/p"), thumbnailURL: URL(string: "https://festicore.test/t"))
    let store = TestStore(initialState: newState()) {
      BearerProfileFeature()
    } withDependencies: {
      $0.bearerUseCase = BearerUseCaseStub(uploadPhoto: { _, imageData in
        #expect(imageData == data)
        return AsyncThrowingStream { continuation in
          continuation.yield(.progress(0.64))
          continuation.yield(.completed(photo))
          continuation.finish()
        }
      })
    }

    await store.send(.view(.photoPicked(data))) { $0.photoUpload = .uploading(data: data, progress: 0) }
    #expect(!store.state.canSave)
    await store.receive(\.async.uploadPhoto)
    await store.receive(\.inner.photoProgress) { $0.photoUpload = .uploading(data: data, progress: 0.64) }
    await store.receive(\.inner.photoUploaded) {
      $0.photoUpload = .idle
      $0.uploadedPhotoData = data
      $0.photoURL = photo.thumbnailURL
    }
  }

  @Test("업로드를 취소하면 전송을 멈추고 이전 사진을 둔다")
  func cancelsUpload() async {
    let data = Data([1])
    let store = TestStore(initialState: newState()) {
      BearerProfileFeature()
    } withDependencies: {
      $0.bearerUseCase = BearerUseCaseStub(uploadPhoto: { _, _ in AsyncThrowingStream { _ in } })
    }

    await store.send(.view(.photoPicked(data))) { $0.photoUpload = .uploading(data: data, progress: 0) }
    await store.receive(\.async.uploadPhoto)
    await store.send(.view(.photoCancelTapped)) { $0.photoUpload = .idle }
  }

  @Test("작은 사진은 이유를 보인다")
  func photoTooSmall() async {
    var state = newState()
    state.photoUpload = .uploading(data: Data([1]), progress: 0)
    let store = TestStore(initialState: state) { BearerProfileFeature() }

    await store.send(.inner(.photoFailed(.photoTooSmall))) {
      $0.photoUpload = .failed("256×256보다 큰 사진을 골라 주세요")
    }
  }

  @Test("공동 기수 초대 코드를 팝업으로 보인다")
  func invites() async {
    let invite = BearerInvite(code: "ABC234", expiresAt: Date(timeIntervalSince1970: 0))
    let store = TestStore(initialState: newState()) {
      BearerProfileFeature()
    } withDependencies: {
      $0.bearerUseCase = BearerUseCaseStub(inviteCoBearer: { _ in invite })
    }

    await store.send(.view(.inviteTapped)) { $0.isInviting = true }
    await store.receive(\.async.invite)
    await store.receive(\.inner.invited) {
      $0.isInviting = false
      $0.destination = .alert(.coBearerInvite(code: "ABC234"))
    }
    await store.send(.destination(.presented(.alert(.confirmTapped)))) { $0.destination = nil }
  }
}
