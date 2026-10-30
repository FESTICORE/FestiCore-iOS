//
//  SVGProcessor.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/30/26.
//

import Kingfisher
import SVGKit
import UIKit

/// 원격 SVG 데이터를 이미지로 바꾸는 Kingfisher 처리기. SVG가 아니면 기본 처리기로 넘긴다.
public struct SVGProcessor: ImageProcessor {
  public let identifier = "io.festiCore.co.svg-processor"

  public init() {}

  public func process(
    item: ImageProcessItem,
    options: KingfisherParsedOptionsInfo
  ) -> KFCrossPlatformImage? {
    switch item {
    case let .image(image):
      return image
    case let .data(data):
      return makeSVGImage(from: data)
        ?? DefaultImageProcessor.default.process(item: item, options: options)
    }
  }
}

/// 캐시에는 원본 SVG 데이터를 그대로 두고, 읽을 때 다시 이미지로 바꾼다.
public struct SVGCacheSerializer: CacheSerializer {
  public init() {}

  public func data(
    with image: KFCrossPlatformImage,
    original: Data?
  ) -> Data? {
    original ?? DefaultCacheSerializer.default.data(with: image, original: original)
  }

  public func image(
    with data: Data,
    options: KingfisherParsedOptionsInfo
  ) -> KFCrossPlatformImage? {
    makeSVGImage(from: data) ?? DefaultCacheSerializer.default.image(with: data, options: options)
  }
}

/// SVG 문서로 보이는 데이터만 SVGKit으로 그린다.
func makeSVGImage(from data: Data) -> UIImage? {
  guard
    let head = String(data: data.prefix(Metric.sniffLength), encoding: .utf8),
    head.contains("<svg")
  else { return nil }
  return SVGKImage(data: data)?.uiImage
}

private enum Metric {
  static let sniffLength = 512
}
