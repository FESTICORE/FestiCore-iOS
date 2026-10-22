//
//  FestiCoreUploadClient.swift
//  FestiCoreNetworkInterface
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

/// 멀티파트 업로드 진입점. 일반 요청과 분리해, 업로드가 필요한 곳만 의존한다.
public protocol FestiCoreUploadClient: Sendable {
  /// 멀티파트 요청을 전송하고 디코딩된 응답을 반환한다.
  func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response
}
