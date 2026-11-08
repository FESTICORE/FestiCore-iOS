import FestiCoreNetworkInterface
import Foundation

public typealias FestivalCrewResponseDTO = BaseResponseDTO<FestivalCrewDataDTO>

public struct FestivalCrewDataDTO: Decodable, Sendable {
  public struct Member: Decodable, Sendable {
    public let userId: String
    public let nickname: String
    public let joinedAt: String
  }

  public let id: String
  public let festivalId: String
  public let name: String
  public let ownerId: String
  public let members: [Member]
  public let inviteCode: String?
  public let inviteExpiresAt: String?
  public let archivedAt: String?
  /// 상세·가입 응답에만 오는 크루원 존·상태
  public let live: FestivalLiveBoardCrewDTO?
}

public typealias FestivalCrewInviteResponseDTO = BaseResponseDTO<FestivalCrewInviteDataDTO>

/// 로그인 없이 보는 초대 미리보기
public struct FestivalCrewInviteDataDTO: Decodable, Sendable {
  public let crewName: String
  public let festivalId: String
  public let festivalName: String?
  public let ownerNickname: String?
  public let memberCount: Int
  public let expiresAt: String
}

public typealias FestivalCrewInviteCodeResponseDTO = BaseResponseDTO<FestivalCrewInviteCodeDataDTO>

/// 크루장이 새로 받은 초대 코드
public struct FestivalCrewInviteCodeDataDTO: Decodable, Sendable {
  public let inviteCode: String
  public let inviteExpiresAt: String
}

/// 상태 공유에서 서버가 확정한 내 상태
struct FestivalCrewStatusDataDTO: Decodable, Sendable {
  let userId: String
  let state: String?
}
