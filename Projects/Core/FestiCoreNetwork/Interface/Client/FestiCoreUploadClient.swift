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

  /// 보낸 비율(0...1)을 알리며 멀티파트 요청을 전송한다. 작업을 취소하면 전송도 취소한다.
  func upload<R: FestiCoreUploadRequest>(
    _ request: R,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws(FestiCoreNetworkError) -> R.Response
}

public extension FestiCoreUploadClient {
  /// 진행률을 낼 수 없는 구현(테스트 대역 등)은 일반 업로드로 보낸다.
  func upload<R: FestiCoreUploadRequest>(
    _ request: R,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws(FestiCoreNetworkError) -> R.Response {
    try await upload(request)
  }
}
