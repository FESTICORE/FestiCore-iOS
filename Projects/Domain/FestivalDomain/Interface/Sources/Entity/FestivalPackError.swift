//
//  FestivalPackError.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

public enum FestivalPackError: Error, Equatable, Sendable {
  /// 테스트·프리뷰에서 주입하지 않은 호출
  case notRegistered
}
