import APIEndpoint
import Dependencies
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import FestivalDomainInterface
import Foundation

/// 공용 인증 세션으로 크루를 만들고 관리하며 서버 응답과 오류를 도메인 값으로 변환한다.
public struct FestivalCrewRepositoryImpl: FestivalCrewRepositoryInterface {
  @Dependency(\.networkClient) private var client
  @Dependency(\.authService) private var authService
  @Dependency(\.uuid) private var uuid

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
  public func gather(
    crewID: String,
    zoneID: String
  ) async throws {
    guard let sessionID = await authService.authenticatedSessionID else {
      throw FestivalCrewError.unauthenticated
    }
    do {
      let response = try await client.send(
        CrewGatherRequest(
          crewID: crewID,
          body: CrewGatherBody(zoneId: zoneID),
          sessionID: sessionID
        ),
        as: BaseResponseDTO<FestivalCrewGatherDataDTO>.self
      )
      guard response.code == "SUCCESS", response.data.zoneId == zoneID,
            response.data.id.map({ !$0.isEmpty }) ?? true else {
        throw FestivalCrewError.invalidResponse
      }
    } catch let error as FestiCoreNetworkError {
      if case let .response(response) = error {
        switch response.httpStatus {
        case 400: throw FestivalCrewError.invalidInput
        case 401: throw FestivalCrewError.unauthenticated
        case 403: throw response.code == "TERMS_REQUIRED" ? FestivalCrewError.termsRequired : .forbidden
        case 410: throw FestivalCrewError.festivalEnded
        case 429: throw FestivalCrewError.cooldown
        default: break
        }
      }
      throw error
    }
  }

  public func detail(crewID: String) async throws -> FestivalCrew {
    let sessionID = try await authenticatedSessionID()
    let crew = try await crew(CrewRequest.detail(
      crewID: crewID,
      sessionID: sessionID
    ))
    guard crew.id == crewID else { throw FestivalCrewError.invalidResponse }
    return crew
  }

  public func updateStatus(
    crewID: String,
    state: FestivalCrewState,
    zoneID: String?
  ) async throws {
    let sessionID = try await authenticatedSessionID()
    let body = CrewStatusBody(
      zoneId: zoneID,
      state: state.rawValue,
      clientAt: Self.clientAt.string(from: Date())
    )
    let response = try await send(
      CrewRequest.status(
        crewID: crewID,
        body: body,
        idempotencyKey: uuid().uuidString,
        sessionID: sessionID
      ),
      as: BaseResponseDTO<FestivalCrewStatusDataDTO>.self
    )
    guard response.code == "SUCCESS", response.data.state == state.rawValue else {
      throw FestivalCrewError.invalidResponse
    }
  }

  public func rotateInvite(crewID: String) async throws -> FestivalCrewInviteCode {
    let sessionID = try await authenticatedSessionID()
    let response = try await send(
      CrewRequest.rotateInvite(
        crewID: crewID,
        sessionID: sessionID
      ),
      as: FestivalCrewInviteCodeResponseDTO.self
    )
    guard response.code == "SUCCESS" else { throw FestivalCrewError.invalidResponse }
    return try response.data.toDomain()
  }

  public func rename(
    crewID: String,
    name: String
  ) async throws -> FestivalCrew {
    let sessionID = try await authenticatedSessionID()
    let crew = try await crew(CrewRequest.rename(
      crewID: crewID,
      body: CrewRenameBody(name: name),
      sessionID: sessionID
    ))
    guard crew.id == crewID, crew.name == name else { throw FestivalCrewError.invalidResponse }
    return crew
  }

  public func removeMember(
    crewID: String,
    userID: String
  ) async throws {
    let sessionID = try await authenticatedSessionID()
    _ = try await send(
      CrewRequest.removeMember(
        crewID: crewID,
        userID: userID,
        sessionID: sessionID
      ),
      as: FestiCoreEmptyResponse.self
    )
  }

  public func transfer(
    crewID: String,
    toUserID: String
  ) async throws -> FestivalCrew {
    let sessionID = try await authenticatedSessionID()
    let crew = try await crew(CrewRequest.transfer(
      crewID: crewID,
      body: CrewTransferBody(toUserId: toUserID),
      sessionID: sessionID
    ))
    guard crew.id == crewID, crew.ownerID == toUserID else { throw FestivalCrewError.invalidResponse }
    return crew
  }

  public func dissolve(crewID: String) async throws {
    let sessionID = try await authenticatedSessionID()
    _ = try await send(
      CrewRequest.dissolve(
        crewID: crewID,
        sessionID: sessionID
      ),
      as: FestiCoreEmptyResponse.self
    )
  }

  public func invite(code: String) async throws -> FestivalCrewInvite {
    let response = try await send(
      CrewRequest.invite(code: code),
      as: FestivalCrewInviteResponseDTO.self
    )
    guard response.code == "SUCCESS" else { throw FestivalCrewError.invalidResponse }
    return try response.data.toDomain(code: code)
  }

  public func join(inviteCode: String) async throws -> FestivalCrew {
    let sessionID = try await authenticatedSessionID()
    return try await crew(CrewRequest.join(
      body: CrewJoinBody(inviteCode: inviteCode),
      sessionID: sessionID
    ))
  }

  public func respondToGather(
    crewID: String,
    gatherID: String,
    response: FestivalCrewGatherResponse
  ) async throws -> FestivalCrewGatherReply {
    let sessionID = try await authenticatedSessionID()
    let request = CrewGatherResponseRequest(
      crewID: crewID,
      gatherID: gatherID,
      body: CrewGatherResponseBody(response: response.rawValue),
      sessionID: sessionID
    )
    do {
      let result = try await client.send(
        request,
        as: BaseResponseDTO<FestivalCrewGatherReplyDataDTO>.self
      )
      guard result.code == "SUCCESS" else { throw FestivalCrewError.invalidResponse }
      return try result.data.toDomain()
    } catch let error as FestiCoreNetworkError {
      // 10분이 지난 모여는 409 `GATHER_EXPIRED`로 온다. 보낸 사람(403 `GATHER_SENDER`)은 공통 403과 같다.
      if case let .response(response) = error, response.httpStatus == 409 {
        throw FestivalCrewError.gatherExpired
      }
      throw Self.map(error)
    }
  }

  public func leave(crewID: String) async throws {
    let sessionID = try await authenticatedSessionID()
    guard let userID = await authService.currentUserID, !userID.isEmpty else {
      throw FestivalCrewError.unauthenticated
    }
    do {
      _ = try await client.send(
        CrewRequest.removeMember(
          crewID: crewID,
          userID: userID,
          sessionID: sessionID
        ),
        as: FestiCoreEmptyResponse.self
      )
    } catch {
      // 크루장은 409 `OWNER_CANNOT_LEAVE`로 막힌다. 넘기거나 해산해야 나갈 수 있다.
      if case let .response(response) = error, response.httpStatus == 409 {
        throw FestivalCrewError.forbidden
      }
      throw Self.map(error)
    }
  }
}

private extension FestivalCrewRepositoryImpl {
  /// 서버가 받는 `clientAt`은 밀리초가 있는 ISO 8601 UTC 문자열이다.
  static let clientAt: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  func authenticatedSessionID() async throws -> UUID {
    guard let sessionID = await authService.authenticatedSessionID else {
      throw FestivalCrewError.unauthenticated
    }
    return sessionID
  }

  func crew(_ request: CrewRequest) async throws -> FestivalCrew {
    let response = try await send(
      request,
      as: FestivalCrewResponseDTO.self
    )
    guard response.code == "SUCCESS" else { throw FestivalCrewError.invalidResponse }
    return try response.data.toDomain()
  }

  func send<T: Decodable & Sendable>(
    _ request: CrewRequest,
    as type: T.Type
  ) async throws -> T {
    do {
      return try await client.send(
        request,
        as: type
      )
    } catch {
      throw Self.map(error)
    }
  }

  /// 크루 관리 응답의 상태·코드를 화면이 고를 수 있는 오류로 바꾼다.
  static func map(_ error: FestiCoreNetworkError) -> any Error {
    guard case let .response(response) = error else { return error }
    switch response.httpStatus {
    case 400: return FestivalCrewError.invalidInput
    case 401: return FestivalCrewError.unauthenticated
    case 403: return response.code == "TERMS_REQUIRED" ? FestivalCrewError.termsRequired : FestivalCrewError.forbidden
    case 404: return FestivalCrewError.notFound
    case 409: return response.code == "CREW_FULL" ? FestivalCrewError.full : FestivalCrewError.alreadyInCrew
    case 410: return FestivalCrewError.festivalEnded
    case 429: return FestivalCrewError.cooldown
    default: return error
    }
  }
}
