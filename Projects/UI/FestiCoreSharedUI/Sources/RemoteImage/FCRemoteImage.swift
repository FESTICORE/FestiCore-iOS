//
//  FCRemoteImage.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/27/26.
//

import FestiCoreDesignKit
import Kingfisher
import SwiftUI

/// 서버 이미지를 캐시해 표시합니다. URL이 없거나 로드에 실패하면 Figma `image=empty`처럼
/// Fill/Strong 바탕에 (지정했다면) 가운데 아이콘을 둔 기본 모양을 표시합니다.
public struct FCRemoteImage: View {
  private let url: URL?
  private(set) var contentMode: SwiftUI.ContentMode = .fill
  private(set) var placeholderIcon: ImageAsset?
  private(set) var placeholderIconSize: CGFloat = 24

  public init(url: URL?) {
    self.url = url
  }

  public var body: some View {
    if let url {
      FCRemoteImageContent(
        url: url,
        contentMode: contentMode,
        placeholder: placeholder
      )
        .id(url)
    } else {
      placeholder
    }
  }

  /// 사진이 없거나 불러오지 못했을 때 가운데에 둘 아이콘(Figma image=empty)을 정합니다.
  public func placeholderIcon(
    _ icon: ImageAsset?,
    size: CGFloat = 24
  ) -> Self {
    var copy = self
    copy.placeholderIcon = icon
    copy.placeholderIconSize = size
    return copy
  }

  /// 표시 영역을 채우거나 이미지 전체가 보이도록 설정합니다.
  public func content(_ mode: SwiftUI.ContentMode) -> Self {
    var copy = self
    copy.contentMode = mode
    return copy
  }
}

private extension FCRemoteImage {
  var placeholder: FCRemoteImagePlaceholder {
    return FCRemoteImagePlaceholder(
      icon: placeholderIcon,
      iconSize: placeholderIconSize
    )
  }
}

/// Figma Thumbnail·Festival Image의 image=empty: Fill/Strong 바탕 + 보조 색 아이콘
private struct FCRemoteImagePlaceholder: View {
  let icon: ImageAsset?
  let iconSize: CGFloat

  var body: some View {
    ZStack {
      FestiCoreSemanticColor.fillStrong.color
      if let icon {
        Image(asset: icon)
          .resizable()
          .frame(
            width: iconSize,
            height: iconSize
          )
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
    }
    .accessibilityHidden(true)
  }
}

private struct FCRemoteImageContent: View {
  let url: URL
  let contentMode: SwiftUI.ContentMode
  let placeholder: FCRemoteImagePlaceholder
  @State private var loadState = LoadState.loading

  private enum LoadState {
    case loading
    case success
    case failure
  }

  var body: some View {
    ZStack {
      if loadState == .failure {
        placeholder
      } else if loadState == .loading {
        FestiCoreSemanticColor.fillNormal.color
      }

      if loadState != .failure {
        KFImage(url)
          .fade(duration: 0.2)
          .placeholder { FCSkeletonView(.rect) }
          .setProcessor(SVGProcessor())
          .serialize(by: SVGCacheSerializer())
          .onSuccess { _ in loadState = .success }
          .onFailure { _ in loadState = .failure }
          .resizable()
          .aspectRatio(contentMode: contentMode)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .clipped()
  }
}
