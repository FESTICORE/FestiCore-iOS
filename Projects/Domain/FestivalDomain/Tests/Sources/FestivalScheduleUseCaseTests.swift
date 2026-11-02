import Dependencies
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalScheduleUseCaseTests {
  @Test func myScheduleReadsServiceSchedule() async throws {
    let service = ScheduleServiceStub(fetchResult: .success(.init(setIDs: ["lime"])))
    let useCase = withDependencies {
      $0.festivalScheduleService = service
    } operation: {
      FestivalScheduleUseCaseImpl()
    }

    let schedule = try await useCase.mySchedule(festivalID: "fst")

    #expect(schedule.setIDs == ["lime"])
    #expect(service.calls.value == ["fetch fst"])
  }

  @Test func saveMySchedulePassesSetIDsAndClientAt() async throws {
    let clientAt = Date(timeIntervalSince1970: 1_786_028_400)
    let service = ScheduleServiceStub(replaceResult: .success(.init(setIDs: ["lime", "noise"])))
    let useCase = withDependencies {
      $0.festivalScheduleService = service
    } operation: {
      FestivalScheduleUseCaseImpl()
    }

    let schedule = try await useCase.saveMySchedule(festivalID: "fst", setIDs: ["lime", "noise"], clientAt: clientAt)

    #expect(schedule.setIDs == ["lime", "noise"])
    #expect(service.calls.value == ["replace fst lime,noise \(clientAt.timeIntervalSince1970)"])
  }

  @Test func scheduleErrorIsPassedThrough() async {
    let service = ScheduleServiceStub(replaceResult: .failure(.stale(.init(setIDs: ["encore"]))))
    let useCase = withDependencies {
      $0.festivalScheduleService = service
    } operation: {
      FestivalScheduleUseCaseImpl()
    }

    await #expect(throws: FestivalScheduleError.stale(.init(setIDs: ["encore"]))) {
      try await useCase.saveMySchedule(festivalID: "fst", setIDs: [], clientAt: .distantPast)
    }
  }
}

private final class ScheduleServiceStub: FestivalScheduleService, @unchecked Sendable {
  let calls = LockIsolated<[String]>([])
  private let fetchResult: Result<FestivalSchedule, FestivalScheduleError>
  private let replaceResult: Result<FestivalSchedule, FestivalScheduleError>

  init(
    fetchResult: Result<FestivalSchedule, FestivalScheduleError> = .success(.init(setIDs: [])),
    replaceResult: Result<FestivalSchedule, FestivalScheduleError> = .success(.init(setIDs: []))
  ) {
    self.fetchResult = fetchResult
    self.replaceResult = replaceResult
  }

  func fetch(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    calls.withValue { $0.append("fetch \(festivalID)") }
    return try fetchResult.get()
  }

  func replace(
    festivalID: String,
    setIDs: [String],
    clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    calls.withValue { $0.append("replace \(festivalID) \(setIDs.joined(separator: ",")) \(clientAt.timeIntervalSince1970)") }
    return try replaceResult.get()
  }
}
