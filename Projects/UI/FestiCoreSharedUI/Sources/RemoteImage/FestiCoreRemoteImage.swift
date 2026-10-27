//
//  FestiCoreRemoteImage.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/27/26.
//

import FestiCoreDesignKit
import Kingfisher
import SwiftUI

/// 서버 이미지를 캐시해 표시합니다. URL이 없거나 로드에 실패하면 의미 색상을 표시합니다.
public struct FestiCoreRemoteImage: View {
  private let url: URL?
  private(set) var contentMode: SwiftUI.ContentMode = .fill

  public init(url: URL?) {
    self.url = url
  }

  public var body: some View {
    FestiCoreSemanticColor.fillNormal.color
      .overlay {
        if let url {
          FestiCoreRemoteImageContent(url: url, contentMode: contentMode)
            .id(url)
        }
      }
    .clipped()
  }

  /// 표시 영역을 채우거나 이미지 전체가 보이도록 설정합니다.
  public func content(_ mode: SwiftUI.ContentMode) -> Self {
    var copy = self
    copy.contentMode = mode
    return copy
  }
}

private struct FestiCoreRemoteImageContent: View {
  let url: URL
  let contentMode: SwiftUI.ContentMode
  @State private var loadFailed = false

  var body: some View {
    if !loadFailed {
      KFImage(url)
        .fade(duration: 0.2)
        .placeholder { ProgressView() }
        .onFailure { _ in loadFailed = true }
        .resizable()
        .aspectRatio(contentMode: contentMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
  }
}
