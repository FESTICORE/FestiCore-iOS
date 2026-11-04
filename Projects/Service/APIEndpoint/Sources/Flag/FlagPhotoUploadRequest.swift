//
//  FlagPhotoUploadRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 11/3/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface
import Foundation

/// `POST flags/:flagId/photo` multipart 업로드. 파일 필드 이름은 `photo`다.
public struct FlagPhotoUploadRequest<Response: Decodable & Sendable>: FestiCoreUploadRequest, Sendable {
  public static var fieldName: String { "photo" }

  public let flagID: String
  public let imageData: Data
  public let mimeType: String
  public let fileName: String
  public let sessionID: UUID

  public init(
    flagID: String,
    imageData: Data,
    mimeType: String = "image/jpeg",
    fileName: String = "photo.jpg",
    sessionID: UUID
  ) {
    self.flagID = flagID
    self.imageData = imageData
    self.mimeType = mimeType
    self.fileName = fileName
    self.sessionID = sessionID
  }

  public var path: String { return FlagAPI.photo(flagID: flagID).path }
  public var method: HTTPMethod { return .post }
  public var authorization: FestiCoreAuthorization { return .sessionBound(sessionID) }
  public var maxRetryAttempts: Int { return 0 }
  /// 셀룰러에서 5MB를 올릴 수 있게 기본보다 길게 기다린다.
  public var timeoutInterval: TimeInterval? { return 60 }

  public var parts: [FestiCoreMultipartPart] {
    return [FestiCoreMultipartPart(name: Self.fieldName, source: .data(imageData), fileName: fileName, mimeType: mimeType)]
  }
}
