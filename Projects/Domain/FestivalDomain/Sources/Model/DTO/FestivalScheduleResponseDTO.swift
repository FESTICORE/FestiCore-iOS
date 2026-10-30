//
//  FestivalScheduleResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreNetworkInterface
import Foundation

public typealias FestivalScheduleResponseDTO = BaseResponseDTO<FestivalScheduleDataDTO>

public struct FestivalScheduleDataDTO: Decodable, Sendable {
  public let setIds: [String]
}
