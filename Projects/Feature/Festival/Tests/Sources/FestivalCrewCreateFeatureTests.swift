import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalCrewCreateFeatureTests {
  @Test("만들면 초대 단계로 바뀌고 크루장 초대 링크를 만든 뒤 크루 화면으로 보낸다")
  func createsCrewThenInvitesAndOpensCrew() async {
    let crew = invitedCrew
    let recorder = CrewCreateCallRecorder()
    let store = TestStore(initialState: FestivalCrewCreateFeature.State(festivalID: "festival-1")) {
      FestivalCrewCreateFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewCreateStub(
        result: .success(crew),
        recorder: recorder
      )
    }

    await store.send(.view(.nameChanged("  우리 크루  "))) {
      $0.name = "  우리 크루  "
    }
    await store.send(.view(.submitTapped)) {
      $0.isSubmitting = true
    }
    await store.receive(.async(.create(
      festivalID: "festival-1",
      name: "우리 크루"
    )))
    await store.receive(.inner(.createSucceeded(crew))) {
      $0.isSubmitting = false
      $0.step = .created(crew)
    }
    await store.receive(.delegate(.created(crew)))
    let calls = await recorder.calls
    #expect(calls == [.init(
      festivalID: "festival-1",
      name: "우리 크루",
      nickname: nil
    )])
    #expect(store.state.inviteURL == URL(string: "festicore://crew/K7P2QX"))

    await store.send(.view(.openCrewTapped))
    await store.receive(.delegate(.openCrewRequested(crewID: "crew-1")))
  }

  @Test("이미 크루가 있거나 끝난 페스티벌이면 입력란 아래에 알리고 이름을 고치면 지운다")
  func showsPermanentFailureInline() async {
    let store = TestStore(initialState: FestivalCrewCreateFeature.State(festivalID: "festival-1")) {
      FestivalCrewCreateFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewCreateStub(result: .failure(.alreadyInCrew))
    }

    await store.send(.view(.nameChanged("우리 크루"))) { $0.name = "우리 크루" }
    await store.send(.view(.submitTapped)) { $0.isSubmitting = true }
    await store.receive(.async(.create(
      festivalID: "festival-1",
      name: "우리 크루"
    )))
    await store.receive(.inner(.createFailed(.alreadyInCrew))) {
      $0.isSubmitting = false
      $0.errorMessage = "이 페스티벌에서 이미 크루에 있어요. 크루는 페스티벌마다 하나만 만들거나 참여할 수 있어요."
    }
    await store.send(.view(.nameChanged("새 크루"))) {
      $0.name = "새 크루"
      $0.errorMessage = nil
    }
  }

  @Test("로그인이 풀렸으면 부모에게 로그인을 요청한다")
  func requestsLoginWhenUnauthenticated() async {
    let store = TestStore(initialState: FestivalCrewCreateFeature.State(festivalID: "festival-1")) {
      FestivalCrewCreateFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewCreateStub(result: .failure(.unauthenticated))
    }

    await store.send(.view(.nameChanged("우리 크루"))) { $0.name = "우리 크루" }
    await store.send(.view(.submitTapped)) { $0.isSubmitting = true }
    await store.receive(.async(.create(
      festivalID: "festival-1",
      name: "우리 크루"
    )))
    await store.receive(.inner(.createFailed(.unauthenticated))) { $0.isSubmitting = false }
    await store.receive(.delegate(.loginRequested))
  }

  @Test("빈 이름과 공백만 있는 이름은 제출되지 않는다")
  func rejectsBlankName() async {
    let store = TestStore(initialState: FestivalCrewCreateFeature.State(festivalID: "festival-1")) {
      FestivalCrewCreateFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewCreateStub(result: .success(sampleCrew))
    }

    await store.send(.view(.submitTapped))
    await store.send(.view(.nameChanged("   "))) { $0.name = "   " }
    await store.send(.view(.submitTapped))
  }

  @Test("생성 실패는 다시 시도할 수 있는 공용 팝업을 보여 준다")
  func showsRetryAlert() async {
    let store = TestStore(initialState: FestivalCrewCreateFeature.State(festivalID: "festival-1")) {
      FestivalCrewCreateFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewCreateStub(result: .failure(.unavailable))
    }

    await store.send(.view(.nameChanged("우리 크루"))) { $0.name = "우리 크루" }
    await store.send(.view(.submitTapped)) { $0.isSubmitting = true }
    await store.receive(.async(.create(
      festivalID: "festival-1",
      name: "우리 크루"
    )))
    await store.receive(.inner(.createFailed(.unavailable))) {
      $0.isSubmitting = false
      $0.alert = .alert(
        title: "크루를 만들지 못했어요",
        message: "연결을 확인하고 다시 시도해 주세요.",
        confirmTitle: "다시 시도",
        cancelTitle: "닫기"
      )
    }
    await store.send(.alert(.presented(.confirmTapped))) { $0.alert = nil }
    await store.receive(.view(.submitTapped)) { $0.isSubmitting = true }
    await store.receive(.async(.create(
      festivalID: "festival-1",
      name: "우리 크루"
    )))
    await store.receive(.inner(.createFailed(.unavailable))) {
      $0.isSubmitting = false
      $0.alert = .alert(
        title: "크루를 만들지 못했어요",
        message: "연결을 확인하고 다시 시도해 주세요.",
        confirmTitle: "다시 시도",
        cancelTitle: "닫기"
      )
    }
  }

  @Test("생성 실패 팝업을 닫으면 이름을 유지하고 재요청하지 않는다")
  func dismissesRetryAlert() async {
    var state = FestivalCrewCreateFeature.State(festivalID: "festival-1")
    state.name = "우리 크루"
    state.alert = .alert(
      title: "크루를 만들지 못했어요",
      message: "연결을 확인하고 다시 시도해 주세요.",
      confirmTitle: "다시 시도",
      cancelTitle: "닫기"
    )
    let store = TestStore(initialState: state) { FestivalCrewCreateFeature() }

    await store.send(.alert(.presented(.cancelTapped))) { $0.alert = nil }
    #expect(store.state.name == "우리 크루")
    #expect(store.state.canSubmit)
    await store.finish()
  }

  private var invitedCrew: FestivalCrew {
    return FestivalCrew(
      id: "crew-1",
      festivalID: "festival-1",
      name: "우리 크루",
      ownerID: "user-1",
      members: [],
      inviteCode: "K7P2QX",
      inviteExpiresAt: Date(timeIntervalSince1970: 1_800_172_800)
    )
  }

  private var sampleCrew: FestivalCrew {
    return FestivalCrew(
      id: "crew-1",
      festivalID: "festival-1",
      name: "우리 크루",
      ownerID: "user-1",
      members: [],
      inviteCode: nil,
      inviteExpiresAt: nil
    )
  }
}

private struct CrewCreateStub: FestivalCrewUseCaseInterface {
  func gather(
    crewID: String,
    zoneID: String
  ) async throws {
    throw FestivalCrewError.unavailable
  }

  let result: Result<FestivalCrew, FestivalCrewError>
  let recorder: CrewCreateCallRecorder?

  init(
    result: Result<FestivalCrew, FestivalCrewError>,
    recorder: CrewCreateCallRecorder? = nil
  ) {
    self.result = result
    self.recorder = recorder
  }

  func create(
    festivalID: String,
    name: String,
    nickname: String?
  ) async throws -> FestivalCrew {
    await recorder?.record(
      festivalID: festivalID,
      name: name,
      nickname: nickname
    )
    return try result.get()
  }
}

private actor CrewCreateCallRecorder {
  struct Call: Equatable, Sendable {
    let festivalID: String
    let name: String
    let nickname: String?
  }

  private(set) var calls: [Call] = []

  func record(
    festivalID: String,
    name: String,
    nickname: String?
  ) {
    calls.append(Call(
      festivalID: festivalID,
      name: name,
      nickname: nickname
    ))
  }
}
