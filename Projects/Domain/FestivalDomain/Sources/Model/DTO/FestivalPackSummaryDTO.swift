//
//  FestivalPackSummaryDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

/// 받은 팩 목록에 필요한 팩 JSON의 일부
struct FestivalPackSummaryDTO: Decodable {
  let name: String?
  let thumbUrl: String?
}
