import Dependencies
import FestivalDomainInterface
import Foundation

/// 크루 생성·관리 입력을 정규화하고 검증한 뒤 저장소에 전달한다.
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
    guard (1 ... 32).contains(festivalID.count), (1 ... FestivalCrew.maxNameLength).contains(name.count),
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

  public func detail(crewID: String) async throws -> FestivalCrew {
    try Self.validate(id: crewID)
    return try await repository.detail(crewID: crewID)
  }

  public func updateStatus(
    crewID: String,
    state: FestivalCrewState,
    zoneID: String?
  ) async throws {
    try Self.validate(id: crewID)
    if let zoneID { try Self.validate(id: zoneID) }
    // 귀가 중은 서버가 존을 비우므로 존을 함께 보내지 않는다.
    try await repository.updateStatus(
      crewID: crewID,
      state: state,
      zoneID: state == .leaving ? nil : zoneID
    )
  }

  public func rotateInvite(crewID: String) async throws -> FestivalCrewInviteCode {
    try Self.validate(id: crewID)
    return try await repository.rotateInvite(crewID: crewID)
  }

  public func rename(
    crewID: String,
    name: String
  ) async throws -> FestivalCrew {
    try Self.validate(id: crewID)
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1 ... FestivalCrew.maxNameLength).contains(name.count) else { throw FestivalCrewError.invalidInput }
    return try await repository.rename(
      crewID: crewID,
      name: name
    )
  }

  public func removeMember(
    crewID: String,
    userID: String
  ) async throws {
    try Self.validate(id: crewID)
    try Self.validate(id: userID)
    try await repository.removeMember(
      crewID: crewID,
      userID: userID
    )
  }

  public func transfer(
    crewID: String,
    toUserID: String
  ) async throws -> FestivalCrew {
    try Self.validate(id: crewID)
    try Self.validate(id: toUserID)
    return try await repository.transfer(
      crewID: crewID,
      toUserID: toUserID
    )
  }

  public func dissolve(crewID: String) async throws {
    try Self.validate(id: crewID)
    try await repository.dissolve(crewID: crewID)
  }

  public func invite(code: String) async throws -> FestivalCrewInvite {
    return try await repository.invite(code: try Self.inviteCode(code))
  }

  public func join(inviteCode: String) async throws -> FestivalCrew {
    return try await repository.join(inviteCode: try Self.inviteCode(inviteCode))
  }

  public func respondToGather(
    crewID: String,
    gatherID: String,
    response: FestivalCrewGatherResponse
  ) async throws -> FestivalCrewGatherReply {
    try Self.validate(id: crewID)
    try Self.validate(id: gatherID)
    let reply = try await repository.respondToGather(
      crewID: crewID,
      gatherID: gatherID,
      response: response
    )
    guard reply.gatherID == gatherID, reply.response == response else {
      throw FestivalCrewError.invalidResponse
    }
    return reply
  }

  public func leave(crewID: String) async throws {
    try Self.validate(id: crewID)
    try await repository.leave(crewID: crewID)
  }
}

private extension FestivalCrewUseCaseImpl {
  /// 서버 ID는 ASCII 영숫자·`-`·`_`만 쓴다. 경로 한 칸을 벗어나는 값은 보내지 않는다.
  static func validate(id: String) throws {
    guard (1 ... 64).contains(id.count),
          id.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }) else {
      throw FestivalCrewError.invalidInput
    }
  }

  /// 초대 코드는 헷갈리는 글자(I·O·0·1)를 뺀 6자리다. 대문자로 맞춰 보낸다.
  static func inviteCode(_ value: String) throws -> String {
    let code = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    guard code.count == 6, code.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
      throw FestivalCrewError.notFound
    }
    return code
  }
}
