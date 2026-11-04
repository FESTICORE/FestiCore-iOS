import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalCrewGatherFeatureTests {
  @Test func submitsOnlyExplicitOfficialZone() async throws {
    let zones = try zones()
    let requests = LockIsolated<[String]>([])
    let store = TestStore(initialState: FestivalCrewGatherFeature.State(
      crewID: "crew_a",
      zones: zones
    )) {
      FestivalCrewGatherFeature()
    } withDependencies: {
      $0.festivalCrewUseCase = GatherStub { crew, zone in
        requests.withValue { $0.append("\(crew)/\(zone)") }
      }
    }
    await store.send(.view(.submitTapped))
    await store.send(.view(.zoneTapped("unknown")))
    await store.send(.view(.zoneTapped("zone_a"))) { $0.selectedZoneID = "zone_a" }
    await store.send(.view(.submitTapped)) { $0.isSubmitting = true }
    await store.receive(\.async.gather)
    await store.receive(\.inner.succeeded) { $0.isSubmitting = false }
    await store.receive(\.delegate.gathered)
    #expect(requests.value == ["crew_a/zone_a"])
  }

  @Test func submittingPreventsDuplicateRequestAndZoneChange() async throws {
    let zones = try zones()
    let store = TestStore(initialState: FestivalCrewGatherFeature.State(
      crewID: "crew_a",
      zones: zones,
      selectedZoneID: "zone_a",
      isSubmitting: true
    )) { FestivalCrewGatherFeature() }
    await store.send(.view(.submitTapped))
    await store.send(.view(.zoneTapped("zone_a")))
  }

  @Test func cooldownPreventsRequest() async throws {
    let now = Date(timeIntervalSince1970: 1000)
    let zones = try zones()
    let store = TestStore(initialState: FestivalCrewGatherFeature.State(
      crewID: "crew_a",
      zones: zones,
      selectedZoneID: "zone_a",
      availableAt: now.addingTimeInterval(60)
    )) {
      FestivalCrewGatherFeature()
    } withDependencies: {
      $0.date.now = now
    }
    await store.send(.view(.submitTapped)) {
      $0.alert = .alert(
        title: "잠시 후 다시 모일 수 있어요",
        message: "크루 집결은 10분에 한 번 요청할 수 있어요."
      )
    }
  }

  private func zones() throws -> [FestivalPackDocument.Zone] {
    return try JSONDecoder().decode(
      [FestivalPackDocument.Zone].self,
      from: Data(#"[{"id":"zone_a","name":"메인"}]"#.utf8)
    )
  }
}

private struct GatherStub: FestivalCrewUseCaseInterface {
  let send: @Sendable (
    String,
    String
  ) -> Void

  func gather(
    crewID: String,
    zoneID: String
  ) async throws {
    send(
      crewID,
      zoneID
    )
  }

  func create(
    festivalID: String,
    name: String,
    nickname: String?
  ) async throws -> FestivalCrew {
    throw FestivalCrewError.unavailable
  }
}
