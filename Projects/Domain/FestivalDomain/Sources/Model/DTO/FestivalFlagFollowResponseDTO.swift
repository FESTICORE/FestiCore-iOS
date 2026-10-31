//
//  FestivalFlagFollowResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 10/31/26.
//

import FestiCoreNetworkInterface
import Foundation

public typealias FestivalFlagFollowResponseDTO = BaseResponseDTO<FestivalFlagFollowDataDTO>

public struct FestivalFlagFollowDataDTO: Decodable, Sendable {
  public let flagId: String
  public let following: Bool
  public let followerCount: Int
}
