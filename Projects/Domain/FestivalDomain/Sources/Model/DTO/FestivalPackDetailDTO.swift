//
//  FestivalPackDetailDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

/// 팩 JSON의 가는 길·준비물·반입 금지 부분. 형식이 다른 값은 버린다.
struct FestivalPackDetailDTO: Decodable {
  let directions: DirectionsDTO?
  let checklist: [ChecklistItemDTO]?
  let rules: [String]?
  let source: SourceDTO?

  private enum CodingKeys: String, CodingKey {
    case directions, checklist, rules, source
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    directions = try? container.decodeIfPresent(DirectionsDTO.self, forKey: .directions)
    checklist = (try? container.decodeIfPresent([LossyChecklistItemDTO].self, forKey: .checklist))?
      .compactMap(\.value)
    rules = (try? container.decodeIfPresent([String?].self, forKey: .rules))?.compactMap { $0 }
    source = try? container.decodeIfPresent(SourceDTO.self, forKey: .source)
  }

  struct DirectionsDTO: Decodable {
    let shuttle: SectionDTO?
    let transit: SectionDTO?
    let parking: SectionDTO?
    let memo: String?
    let lastShuttleAt: String?
    let lastTrainAt: String?
    let mapLinks: MapLinksDTO?
    let source: SourceDTO?
  }

  struct SectionDTO: Decodable {
    let body: String?
    let links: [LinkDTO]?
    let stationName: String?
    let walkMinutes: Int?
  }

  struct LinkDTO: Decodable {
    let label: String?
    let url: String?
  }

  struct MapLinksDTO: Decodable {
    let naver: String?
    let kakao: String?
  }

  struct ChecklistItemDTO: Decodable {
    let id: String
    let label: String
    let required: Bool?
    let note: String?
  }

  struct SourceDTO: Decodable {
    let name: String?
    let verifiedAt: String?
  }

  private struct LossyChecklistItemDTO: Decodable {
    let value: ChecklistItemDTO?

    init(from decoder: Decoder) throws {
      value = try? ChecklistItemDTO(from: decoder)
    }
  }
}
