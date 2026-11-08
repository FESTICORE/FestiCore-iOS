//
//  FestivalLiveDependencies.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//
//  이 모듈이 소유한 UseCase·Repository live 구현을 스스로 등록한다.
//  저장소·시스템 클라이언트의 live 구현은 각 기능 폴더의 `+Live` 파일에 둔다.
//

import Dependencies
import FestivalDomainInterface

extension FestivalReceivedPackUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalReceivedPackUseCaseInterface { return FestivalReceivedPackUseCaseImpl() }
}

extension FestivalPackDetailUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalPackDetailUseCaseInterface { return FestivalPackDetailUseCaseImpl() }
}

extension FestivalPackRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalPackRepositoryInterface { return FestivalPackRepositoryImpl() }
}

extension FestivalNotificationSettingsUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalNotificationSettingsUseCaseInterface {
    return FestivalNotificationSettingsUseCaseImpl()
  }
}

extension FestivalFlagDetailRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalFlagDetailRepositoryInterface { return FestivalFlagDetailRepositoryImpl() }
}

extension FestivalFlagDetailUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalFlagDetailUseCaseInterface { return FestivalFlagDetailUseCaseImpl() }
}

extension FestivalZoneMapRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalZoneMapRepositoryInterface { return FestivalZoneMapRepositoryImpl() }
}

extension FestivalZoneMapUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalZoneMapUseCaseInterface { return FestivalZoneMapUseCaseImpl() }
}

extension FestivalCatalogRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalCatalogRepositoryInterface {
    return FestivalCatalogRepositoryImpl()
  }
}

extension FestivalCatalogUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalCatalogUseCaseInterface { return FestivalCatalogUseCaseImpl() }
}

extension FestivalCrewRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalCrewRepositoryInterface { return FestivalCrewRepositoryImpl() }
}

extension FestivalCrewUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalCrewUseCaseInterface { return FestivalCrewUseCaseImpl() }
}

extension FestivalFlagUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalFlagUseCaseInterface { return FestivalFlagUseCaseImpl() }
}

extension FestivalGuideVisibilityUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalGuideVisibilityUseCaseInterface {
    return FestivalGuideVisibilityUseCaseImpl()
  }
}

extension FestivalImageUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalImageUseCaseInterface { return FestivalImageUseCaseImpl() }
}

extension FestivalLibraryUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalLibraryUseCaseInterface { return FestivalLibraryUseCaseImpl() }
}

extension FestivalLiveActivityUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalLiveActivityUseCaseInterface { return FestivalLiveActivityUseCaseImpl() }
}

extension FestivalLiveBoardUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalLiveBoardUseCaseInterface { return FestivalLiveBoardUseCaseImpl() }
}

extension FestivalPackSyncRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalPackSyncRepositoryInterface {
    return FestivalPackSyncRepositoryImpl()
  }
}

extension FestivalPackUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalPackUseCaseInterface { return FestivalPackUseCaseImpl() }
}

extension FestivalScheduleUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalScheduleUseCaseInterface { return FestivalScheduleUseCaseImpl() }
}
