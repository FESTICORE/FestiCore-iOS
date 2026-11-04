import Dependencies
import FestivalDomainInterface
import Foundation

/// 크루 생성 입력을 정규화하고 검증한 뒤 저장소에 전달한다.
public struct FestivalCrewUseCaseImpl: FestivalCrewUseCaseInterface {
  @Dependency(\.festivalCrewRepository) private var repository

  public init() {}

  public func create(
    festivalID: String,
    name: String,
    nickname: String? = nil
  ) async throws -> FestivalCrew {
    let festivalID = festivalID.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1 ... 32).contains(festivalID.count), (1 ... 20).contains(name.count),
          nickname.map({ (1 ... 12).contains($0.count) }) ?? true else {
      throw FestivalCrewError.invalidInput
    }
    return try await repository.create(
      festivalID: festivalID,
      name: name,
      nickname: nickname
    )
  }
  public func gather(
    crewID: String,
    zoneID: String
  ) async throws {
    guard !crewID.isEmpty, !zoneID.isEmpty,
          crewID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
      throw FestivalCrewError.invalidInput
    }
    try await repository.gather(
      crewID: crewID,
      zoneID: zoneID
    )
  }

}
