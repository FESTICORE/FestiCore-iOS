import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalCrewCreateFeatureTests {
  @Test("유효한 크루 이름은 앞뒤 공백을 제거해 생성하고 결과를 부모에게 전달한다")
  func createsCrew() async {
    let crew = sampleCrew
    let recorder = CrewCreateCallRecorder()
    let store = TestStore(initialState: FestivalCrewCreateFeature.State(festivalID: "festival-1")) {
      FestivalCrewCreateFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = CrewCreateStub(result: .success(crew), recorder: recorder)
    }

    await store.send(.view(.nameChanged("  우리 크루  "))) {
      $0.name = "  우리 크루  "
    }
    await store.send(.view(.submitTapped)) {
      $0.isSubmitting = true
    }
    await store.receive(.async(.create(festivalID: "festival-1", name: "우리 크루")))
    await store.receive(.inner(.createSucceeded(crew))) {
      $0.isSubmitting = false
    }
    await store.receive(.delegate(.created(crew)))
    let calls = await recorder.calls
    #expect(calls == [.init(festivalID: "festival-1", name: "우리 크루", nickname: nil)])
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
    await store.receive(.async(.create(festivalID: "festival-1", name: "우리 크루")))
    await store.receive(.inner(.createFailed)) {
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
    await store.receive(.async(.create(festivalID: "festival-1", name: "우리 크루")))
    await store.receive(.inner(.createFailed)) {
      $0.isSubmitting = false
      $0.alert = .alert(
        title: "크루를 만들지 못했어요",
        message: "연결을 확인하고 다시 시도해 주세요.",
        confirmTitle: "다시 시도",
        cancelTitle: "닫기"
      )
    }
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
  let result: Result<FestivalCrew, FestivalCrewError>
  let recorder: CrewCreateCallRecorder?

  init(result: Result<FestivalCrew, FestivalCrewError>, recorder: CrewCreateCallRecorder? = nil) {
    self.result = result
    self.recorder = recorder
  }

  func create(festivalID: String, name: String, nickname: String?) async throws -> FestivalCrew {
    await recorder?.record(festivalID: festivalID, name: name, nickname: nickname)
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

  func record(festivalID: String, name: String, nickname: String?) {
    calls.append(Call(festivalID: festivalID, name: name, nickname: nickname))
  }
}
