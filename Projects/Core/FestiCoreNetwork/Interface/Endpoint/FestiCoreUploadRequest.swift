//
//  FestiCoreUploadRequest.swift
//  FestiCoreNetworkInterface
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

/// 멀티파트 업로드 요청. 엔드포인트 메타는 `FestiCoreEndpoint`, 바디는 `parts` 로 표현한다.
/// 실제 MultipartFormData 조립 / 전송은 구현(FestiCoreNetwork)이 Alamofire 로 처리한다.
public protocol FestiCoreUploadRequest: FestiCoreEndpoint {
  /// 디코딩될 응답 타입
  associatedtype Response: Decodable & Sendable = FestiCoreEmptyResponse
  /// 멀티파트 바디를 구성하는 파트들
  var parts: [FestiCoreMultipartPart] { get }
}
