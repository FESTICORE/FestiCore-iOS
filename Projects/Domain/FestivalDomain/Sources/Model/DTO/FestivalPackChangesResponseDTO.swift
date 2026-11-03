//
//  FestivalPackChangesResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

struct FestivalPackChangesResponseDTO: Decodable, Sendable {
  let code: String
  let data: FestivalPackChangesDataDTO
}

struct FestivalPackChangesDataDTO: Decodable, Sendable {
  let fromVersion: Int
  let toVersion: Int
  let sizeBytes: Int
  let changedSets: Int?
  let lastShuttleAt: ValueChangeDTO?
  let lastTrainAt: ValueChangeDTO?

  struct ValueChangeDTO: Decodable, Sendable {
    let before: String?
    let after: String?
  }
}
