//
//  BearerLiveDependencies.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Dependencies

extension BearerRepositoryDependency: DependencyKey {
  public static var liveValue: any BearerRepositoryInterface { BearerRepositoryImpl() }
}

extension BearerStatusOutboxDependency: DependencyKey {
  /// 앱 전체에서 하나만 둔다. 보드를 닫아도 전송이 이어진다.
  public static let liveValue: any BearerStatusOutboxInterface = BearerStatusOutboxImpl()
}

extension BearerUseCaseDependency: DependencyKey {
  public static var liveValue: any BearerUseCaseInterface { BearerUseCaseImpl() }
}
