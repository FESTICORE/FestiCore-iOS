//
//  NetworkClientDependency.swift
//  FestiCoreNetworkInterface
//
//  Created by FestiCore on 2026-09-02
//
//  네트워크 클라이언트의 DependencyKey.
//
//  실제 인증 클라이언트는 앱 조립 계층이 `DependencyValues`에 등록한다.
//  Interface 모듈에는 계약과 테스트 기본값만 둔다.
//

import Foundation

import Dependencies

public enum NetworkClientDependency: TestDependencyKey {
  public static var testValue: any FestiCoreNetworkClient {
    return UnimplementedNetworkClient()
  }
}

public extension DependencyValues {
  var networkClient: any FestiCoreNetworkClient {
    get {
      return self[NetworkClientDependency.self]
    }
    set { self[NetworkClientDependency.self] = newValue }
  }
}

/// 테스트에서 클라이언트를 갈아끼우지 않은 채 네트워크를 타면 오류를 반환하는 기본값.
public struct UnimplementedNetworkClient: FestiCoreNetworkClient {
  public init() {}

  public func send<R: FestiCoreDataRequest, T: Decodable & Sendable>(
    _ request: R,
    as type: T.Type
  ) async throws(FestiCoreNetworkError) -> T {
    throw .request(.dependencyNotRegistered("networkClient"))
  }

  public func send<R: FestiCoreDataRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.dependencyNotRegistered("networkClient"))
  }

  public func sendResponse<R: FestiCoreDataRequest>(
    _ request: R
  ) async throws(FestiCoreNetworkError) -> FestiCoreHTTPResponse {
    throw .request(.dependencyNotRegistered("networkClient"))
  }

  public func upload<R: FestiCoreUploadRequest>(_ request: R) async throws(FestiCoreNetworkError) -> R.Response {
    throw .request(.dependencyNotRegistered("networkClient"))
  }

  public func upload(_ request: some FestiCoreFileUploadRequest) async throws(FestiCoreNetworkError) {
    throw .request(.dependencyNotRegistered("networkClient"))
  }
}
