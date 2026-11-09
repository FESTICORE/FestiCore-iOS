//
//  FestivalPackDownloadDisplay.swift
//  Festival
//
//  Created by FestiCore on 11/9/26.
//

import Foundation

/// 팩 받는 중 진행 표시. 목록 카드와 라이브 보드가 같은 값을 쓴다.
struct FestivalPackDownloadDisplay: Equatable {
  /// 받은 바이트 비율(0...1). 전체 크기를 모르면 nil이라 진행 바 없이 받는 중만 보인다.
  let progress: Double?
  /// "팩 받는 중 · 62%" 또는 "팩 받는 중"
  let text: String
}

extension FestivalFeature.State {
  /// 이 축제의 팩을 받는 중이면 UseCase가 알려 준 진행률로 표시 값을 만든다. 받는 중이 아니면 nil이다.
  func packDownloadDisplay(for festivalID: String?) -> FestivalPackDownloadDisplay? {
    guard let festivalID,
          case let .downloading(progress) = packDownloads[festivalID] else { return nil }
    let fraction = progress.flatMap { value -> Double? in
      guard value.totalBytes > 0 else { return nil }
      return min(
        max(
          Double(value.receivedBytes) / Double(value.totalBytes),
          0
        ),
        1
      )
    }
    return FestivalPackDownloadDisplay(
      progress: fraction,
      text: fraction.map { "팩 받는 중 · \(Int(($0 * 100).rounded()))%" } ?? "팩 받는 중"
    )
  }
}
