//
//  BearerPhotoEncoder.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 업로드 전 사진을 서버 규격에 맞춘다: JPEG, 5MB 이하, 짧은 변 256px 이상.
struct BearerPhotoEncoder: Sendable {
  static let maxBytes = 5 * 1024 * 1024
  static let minSide = 256
  /// 긴 변을 이 크기로 줄인다. 서버의 해상도 상한과 업로드 시간을 함께 줄인다.
  static let maxSide = 2048
  private static let qualities: [Double] = [0.85, 0.75, 0.65, 0.55, 0.45, 0.35]

  func encode(_ data: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) > 0,
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
      throw BearerError.unsupportedPhoto
    }
    let shortSide = min(width, height)
    let longSide = max(width, height)
    guard shortSide >= Self.minSide else { throw BearerError.photoTooSmall }

    // 긴 변을 줄여도 짧은 변이 256px 밑으로 내려가지 않게 한다.
    let keepsShortSide = Int((Double(Self.minSide) * Double(longSide) / Double(shortSide)).rounded(.up))
    let targetLongSide = min(longSide, max(Self.maxSide, keepsShortSide))
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: targetLongSide
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw BearerError.unsupportedPhoto
    }
    for quality in Self.qualities {
      if let jpeg = Self.jpeg(image, quality: quality), jpeg.count <= Self.maxBytes {
        return jpeg
      }
    }
    throw BearerError.photoTooLarge
  }

  private static func jpeg(_ image: CGImage, quality: Double) -> Data? {
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      output, UTType.jpeg.identifier as CFString, 1, nil
    ) else { return nil }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return output as Data
  }
}
