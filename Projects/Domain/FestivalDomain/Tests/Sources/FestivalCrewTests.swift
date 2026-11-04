import Dependencies
import FestivalDomainInterface
import Foundation
import Testing
@testable import FestivalDomain

@Suite("크루 생성 유스케이스")
struct FestivalCrewTests {
  @Test func trimsValidInputAndCallsRepository() async throws {
    let repository = RecordingCrewRepository()
    let useCase = withDependencies {
      $0.festivalCrewRepository = repository
    } operation: {
      FestivalCrewUseCaseImpl()
    }
    let crew = try await useCase.create(festivalID: " fst_1 ", name: " 친구들 ", nickname: " 로이 ")
    #expect(crew.name == "친구들")
    #expect(await repository.input == .init(festivalID: "fst_1", name: "친구들", nickname: "로이"))
  }

  @Test func rejectsInvalidInputBeforeNetwork() async {
    let repository = RecordingCrewRepository()
    let useCase = withDependencies {
      $0.festivalCrewRepository = repository
    } operation: {
      FestivalCrewUseCaseImpl()
    }
    await #expect(throws: FestivalCrewError.invalidInput) {
      try await useCase.create(festivalID: "fst_1", name: "   ", nickname: nil)
    }
    await #expect(throws: FestivalCrewError.invalidInput) {
      try await useCase.create(festivalID: "fst_1", name: "친구들", nickname: " ")
    }
    #expect(await repository.input == nil)
  }

  @Test func mapsValidServerResponseAndRejectsMalformedDate() throws {
    let valid = Data(#"{"id":"flg_1","festivalId":"fst_1","name":"친구들","ownerId":"usr_1","members":[{"userId":"usr_1","nickname":"로이","joinedAt":"2026-10-21T01:00:00.000Z"}],"inviteCode":"K7P2QX","inviteExpiresAt":"2026-10-23T01:00:00.000Z"}"#.utf8)
    let dto = try JSONDecoder().decode(FestivalCrewDataDTO.self, from: valid)
    let crew = try dto.toDomain()
    #expect(crew.id == "flg_1")
    #expect(crew.members.first?.nickname == "로이")
    #expect(crew.inviteCode == "K7P2QX")

    let invalid = Data(#"{"id":"flg_1","festivalId":"fst_1","name":"친구들","ownerId":"usr_1","members":[{"userId":"usr_1","nickname":"로이","joinedAt":"bad"}],"inviteCode":null,"inviteExpiresAt":null}"#.utf8)
    let invalidDTO = try JSONDecoder().decode(FestivalCrewDataDTO.self, from: invalid)
    #expect(throws: FestivalCrewError.invalidResponse) { try invalidDTO.toDomain() }
  }
}

private actor RecordingCrewRepository: FestivalCrewRepositoryInterface {
  struct Input: Equatable, Sendable {
    let festivalID: String
    let name: String
    let nickname: String?
  }

  private(set) var input: Input?

  func create(festivalID: String, name: String, nickname: String?) async throws -> FestivalCrew {
    input = Input(festivalID: festivalID, name: name, nickname: nickname)
    return FestivalCrew(
      id: "flg_1", festivalID: festivalID, name: name, ownerID: "usr_1",
      members: [], inviteCode: "K7P2QX", inviteExpiresAt: nil
    )
  }
}
