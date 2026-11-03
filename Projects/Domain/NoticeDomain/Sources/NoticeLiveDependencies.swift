//
//  NoticeLiveDependencies.swift
//  NoticeDomain
//

import Dependencies
import NoticeDomainInterface

extension NoticeRepositoryDependency: DependencyKey {
  public static var liveValue: any NoticeRepositoryInterface { NoticeRepositoryImpl() }
}

extension NoticeUseCaseDependency: DependencyKey {
  public static var liveValue: any NoticeUseCaseInterface { NoticeUseCaseImpl() }
}
