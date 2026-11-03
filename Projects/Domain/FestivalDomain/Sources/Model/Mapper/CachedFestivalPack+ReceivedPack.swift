//
//  CachedFestivalPack+ReceivedPack.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import FestiCorePackInterface
import FestivalDomainInterface
import Foundation

extension CachedFestivalPack {
  /// 축제 목록에 같은 축제가 있으면 이름·썸네일·최신 버전을 목록 값으로 쓴다.
  func receivedPack(
    catalogItem: FestivalCatalogItem?,
    imageURL: (String?) -> URL?
  ) -> FestivalReceivedPack {
    let summary = try? JSONDecoder().decode(FestivalPackSummaryDTO.self, from: pack)
    let name = catalogItem?.name ?? summary?.name ?? festivalID
    return FestivalReceivedPack(
      id: festivalID,
      name: name,
      thumbnailURL: catalogItem?.thumbnailURL ?? imageURL(summary?.thumbUrl),
      packVersion: packVersion,
      latestPackVersion: catalogItem?.packVersion,
      checkedAt: checkedAt,
      sizeBytes: pack.count
    )
  }
}

extension Array where Element == CachedFestivalPack {
  /// 최근에 확인한 팩부터 보여 준다.
  func receivedPacks(
    catalog: [FestivalCatalogItem],
    imageURL: (String?) -> URL?
  ) -> [FestivalReceivedPack] {
    let items = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    return map { $0.receivedPack(catalogItem: items[$0.festivalID], imageURL: imageURL) }
      .sorted {
        let lhs = $0.checkedAt ?? .distantPast
        let rhs = $1.checkedAt ?? .distantPast
        return lhs == rhs ? $0.id < $1.id : lhs > rhs
      }
  }
}
