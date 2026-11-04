import Dependencies
import FestivalDomainInterface
import Foundation

public struct FestivalCrewUseCaseImpl: FestivalCrewUseCaseInterface {
  @Dependency(\.festivalCrewRepository) private var repository

  public init() {}

  public func create(festivalID: String, name: String, nickname: String? = nil) async throws -> FestivalCrew {
    let festivalID = festivalID.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1 ... 32).contains(festivalID.count), (1 ... 20).contains(name.count),
          nickname.map({ (1 ... 12).contains($0.count) }) ?? true else {
      throw FestivalCrewError.invalidInput
    }
    return try await repository.create(festivalID: festivalID, name: name, nickname: nickname)
  }
}
