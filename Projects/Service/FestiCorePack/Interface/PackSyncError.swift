//
//  PackSyncError.swift
//  FestiCorePackInterface
//
//  Created by FestiCore on 11/3/26.
//

/// 팩 동기화 실패 이유. Domain이 오프라인·시간 초과를 구분할 수 있게 Interface에 둔다.
public enum PackSyncError: Error, Sendable, Equatable {
  case unconfigured
  case invalidFestivalID
  case invalidEndpoint
  case invalidMessage
  case invalidPack
  case invalidChunk
  case timeout
  case packTooLarge
  /// 응답을 기다리는 동안 사용자가 팩을 지웠다.
  case packDeleted
  case server(String)
}
