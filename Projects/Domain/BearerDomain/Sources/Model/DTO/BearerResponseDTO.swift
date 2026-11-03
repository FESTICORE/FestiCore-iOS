//
//  BearerResponseDTO.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreNetworkInterface
import Foundation

typealias BearerBoardResponseDTO = BaseResponseDTO<BearerBoardDataDTO>
typealias BearerClaimResponseDTO = BaseResponseDTO<BearerClaimDataDTO>
typealias BearerProfileResponseDTO = BaseResponseDTO<BearerFlagProfileDTO>
typealias BearerStatusResponseDTO = BaseResponseDTO<BearerFlagStatusDTO>
typealias BearerPhotoResponseDTO = BaseResponseDTO<BearerPhotoDataDTO>
typealias BearerInviteResponseDTO = BaseResponseDTO<BearerInviteDataDTO>

struct BearerFlagProfileDTO: Decodable, Sendable, Equatable {
  let id: String
  let name: String
  let thumbUrl: String?
  let photoUrl: String?
  let tags: [String]?
  let bio: String?
  let followerCount: Int?
  let planVisible: Bool?
  let plan: [String]?
  let homeZoneId: String?
}

struct BearerFlagStatusDTO: Decodable, Sendable, Equatable {
  let flagId: String
  let status: String
  let zoneId: String?
  let activity: String?
  let updatedAt: String
  let updatedBy: BearerCoBearerDTO?
}

struct BearerCoBearerDTO: Decodable, Sendable, Equatable {
  let userId: String
  let nickname: String?
}

struct BearerBoardDataDTO: Decodable, Sendable, Equatable {
  let flag: BearerFlagProfileDTO
  let status: BearerFlagStatusDTO
  let followerCount: Int?
  let coBearers: [BearerCoBearerDTO]?
  let hidden: Bool?
  let restartUsedToday: Bool?
}

struct BearerClaimDataDTO: Decodable, Sendable, Equatable {
  let flagId: String
  let flag: BearerFlagProfileDTO
  let isNew: Bool?
  let coBearers: [String]?
}

struct BearerPhotoDataDTO: Decodable, Sendable, Equatable {
  let photoUrl: String?
  let thumbUrl: String?
}

struct BearerInviteDataDTO: Decodable, Sendable, Equatable {
  let code: String
  let expiresAt: String
}

/// 오류 응답 `{code, data, message}`. 잠금은 `data.retryAfter`(초)로 온다.
struct BearerErrorBodyDTO: Decodable, Sendable, Equatable {
  struct Detail: Decodable, Sendable, Equatable {
    let retryAfter: Int?
    let remainingAttempts: Int?
  }

  let code: String?
  let data: Detail?
}
