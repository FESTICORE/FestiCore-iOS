//
//  FestivalPackScheduleDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/13/26.
//

/// 팩 자동 삭제 시점을 정하는 데 필요한 팩 JSON의 일자 목록
struct FestivalPackScheduleDTO: Decodable {
  struct Day: Decodable {
    let endsAt: String?
  }

  let days: [Day]?
}
