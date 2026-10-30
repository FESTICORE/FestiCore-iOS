//
//  FestivalScheduleResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 10/30/26.
//

import Foundation

public struct FestivalScheduleResponseDTO: Decodable, Sendable {
  public let code: String
  public let data: Data

  public struct Data: Decodable, Sendable {
    public let setIds: [String]
  }
}
