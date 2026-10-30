//
//  RequestError.swift
//  FestiCoreNetworkInterface
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

/// 전송 전 — URLRequest 생성 / 파라미터 인코딩 단계 오류.
public enum RequestError: Error {
  /// baseURL 이 없거나 경로 조합이 잘못됨
  case invalidURL
  /// 파라미터 인코딩 실패
  case encodingFailed(any Error)
  /// 요청에 필요한 서비스가 주입되지 않음
  case dependencyNotRegistered(String)
}
