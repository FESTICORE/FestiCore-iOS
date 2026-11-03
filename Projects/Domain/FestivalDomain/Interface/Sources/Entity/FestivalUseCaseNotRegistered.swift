//
//  FestivalUseCaseNotRegistered.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

/// 테스트·프리뷰 Mock에서 주입하지 않은 호출이 던지는 오류.
public struct FestivalUseCaseNotRegistered: Error, Equatable {
  public init() {}
}
