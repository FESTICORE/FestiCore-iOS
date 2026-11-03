//
//  FestivalNotificationSettingsResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

struct FestivalNotificationSettingsResponseDTO: Decodable, Sendable {
  let code: String
  let data: FestivalNotificationSettingsDataDTO
}

struct FestivalNotificationSettingsDataDTO: Decodable, Sendable {
  let flagStatus: Bool
  let crewStatus: Bool
  let crewGather: Bool
  let setReminders: Bool
  let homecoming: Bool
  let packUpdates: Bool
}
