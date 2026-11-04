import APIEndpoint
import Dependencies
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestivalDomainInterface

/// 공용 인증 세션으로 크루를 생성하고 서버 응답과 오류를 도메인 값으로 변환한다.
public struct FestivalCrewRepositoryImpl: FestivalCrewRepositoryInterface {
  @Dependency(\.networkClient) private var client
  @Dependency(\.authService) private var authService

  public init() {}

  public func create(
    festivalID: String,
    name: String,
    nickname: String?
  ) async throws -> FestivalCrew {
    guard let sessionID = await authService.authenticatedSessionID else {
      throw FestivalCrewError.unauthenticated
    }
    let request = CrewRequest.create(
      body: FestivalCrewCreateBodyMapper.body(
        festivalID: festivalID,
        name: name,
        nickname: nickname
      ),
      sessionID: sessionID
    )
    do {
      let response = try await client.send(
        request,
        as: FestivalCrewResponseDTO.self
      )
      guard response.code == "SUCCESS" else { throw FestivalCrewError.invalidResponse }
      let crew = try response.data.toDomain()
      guard crew.festivalID == festivalID else { throw FestivalCrewError.invalidResponse }
      return crew
    } catch let error as FestiCoreNetworkError {
      if case let .response(response) = error {
        switch (
          response.httpStatus,
          response.code
        ) {
        case (
          400,
          _
        ): throw FestivalCrewError.invalidInput
        case (
          401,
          _
        ): throw FestivalCrewError.unauthenticated
        case (
          403,
          "TERMS_REQUIRED"
        ): throw FestivalCrewError.termsRequired
        case (
          409,
          "CREW_ALREADY_IN"
        ): throw FestivalCrewError.alreadyInCrew
        case (
          410,
          _
        ): throw FestivalCrewError.festivalEnded
        default: break
        }
      }
      throw error
    }
  }
}
