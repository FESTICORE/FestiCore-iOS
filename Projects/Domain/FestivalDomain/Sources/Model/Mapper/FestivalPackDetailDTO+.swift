//
//  FestivalPackDetailDTO+.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import FestivalDomainInterface
import Foundation

extension FestivalPackDetailDTO {
  func toDomain(pack: FestivalReceivedPack) -> FestivalPackDetail {
    FestivalPackDetail(
      pack: pack,
      directions: directions?.toDomain() ?? .init(),
      checklist: (checklist ?? []).compactMap { $0.toDomain() },
      rules: (rules ?? []).compactMap(\.nonEmpty),
      source: source?.toDomain()
    )
  }
}

extension FestivalPackDetailDTO.DirectionsDTO {
  func toDomain() -> FestivalPackDetail.Directions {
    FestivalPackDetail.Directions(
      lastShuttleAt: lastShuttleAt?.nonEmpty,
      lastTrainAt: lastTrainAt?.nonEmpty,
      shuttle: shuttle?.toDomain(),
      transit: transit?.toDomain(),
      parking: parking?.toDomain(),
      memo: memo?.nonEmpty,
      naverMapURL: mapLinks?.naver.flatMap(httpsURL),
      kakaoMapURL: mapLinks?.kakao.flatMap(httpsURL),
      source: source?.toDomain()
    )
  }
}

extension FestivalPackDetailDTO.SectionDTO {
  /// 본문·링크·역 정보가 모두 없으면 섹션을 숨긴다.
  func toDomain() -> FestivalPackDetail.Section? {
    let links = (links ?? []).compactMap { link -> FestivalPackDetail.Link? in
      guard let label = link.label?.nonEmpty, let url = link.url.flatMap(httpsURL) else { return nil }
      return FestivalPackDetail.Link(label: label, url: url)
    }
    let body = body?.nonEmpty
    let station = stationName?.nonEmpty
    guard body != nil || !links.isEmpty || station != nil else { return nil }
    return FestivalPackDetail.Section(body: body, links: links, stationName: station, walkMinutes: walkMinutes)
  }
}

extension FestivalPackDetailDTO.ChecklistItemDTO {
  func toDomain() -> FestivalPackDetail.ChecklistItem? {
    guard let label = label.nonEmpty, !id.isEmpty else { return nil }
    return FestivalPackDetail.ChecklistItem(id: id, label: label, required: required ?? false, note: note?.nonEmpty)
  }
}

extension FestivalPackDetailDTO.SourceDTO {
  func toDomain() -> FestivalPackDetail.Source? {
    guard let name = name?.nonEmpty else { return nil }
    return FestivalPackDetail.Source(
      name: name,
      verifiedAt: verifiedAt.flatMap { try? Date($0, strategy: .iso8601) }
    )
  }
}

extension FestivalPackChangesDataDTO {
  func toDomain() -> FestivalPackChanges {
    FestivalPackChanges(
      fromVersion: fromVersion,
      toVersion: toVersion,
      sizeBytes: sizeBytes,
      changedSets: changedSets,
      lastShuttleAt: lastShuttleAt.map { .init(before: $0.before, after: $0.after) },
      lastTrainAt: lastTrainAt.map { .init(before: $0.before, after: $0.after) }
    )
  }
}

private func httpsURL(_ value: String) -> URL? {
  guard let url = URL(string: value), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
  return url
}

private extension String {
  var nonEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
