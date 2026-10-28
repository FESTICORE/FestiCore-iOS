//
//  Modules.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public enum FeatureModule: String, CaseIterable {
  case assembly = "FeatureAssembly"
  case home = "Home"

  var path: Path { .relativeToFeature(rawValue) }
}

public enum CoreModule: String, CaseIterable {
  case assembly = "CoreAssembly"
  case logger = "FestiCoreLogger"
  case network = "FestiCoreNetwork"
  case storage = "FestiCoreStorage"

  var path: Path { .relativeToCore(rawValue) }
}

public enum DomainModule: String, CaseIterable {
  case auth = "AuthDomain"
  case festival = "FestivalDomain"

  var path: Path { .relativeToDomain(rawValue) }
}

public enum UIModule: String, CaseIterable {
  case animation = "FestiCoreAnimation"
  case designSystem = "FestiCoreDesignKit"
  case liveActivity = "FestiCoreLiveActivity"
  case sharedUI = "FestiCoreSharedUI"

  var path: Path { .relativeToUI(rawValue) }
}

public enum WidgetModule: String, CaseIterable {
  case liveActivity = "FestiCoreLiveActivityWidget"

  var path: Path { .relativeToWidget(rawValue) }
  var targetName: String { "FestiCoreLiveActivityExtension" }
}

public enum ExtensionModule: String, CaseIterable {
  case notificationService = "FestiCoreNotificationService"

  var path: Path { .relativeToExtension(rawValue) }
  var targetName: String { "FestiCoreNotificationServiceExtension" }
}

public enum ServiceModule: String, CaseIterable {
  case api = "API"
  case apiEndpoint = "APIEndpoint"
  case analytics = "FestiCoreAnalytics"
  case auth = "FestiCoreAuth"
  case config = "FestiCoreConfig"
  case festivalCatalog = "FestiCoreFestivalCatalog"
  case device = "FestiCoreDevice"
  case pack = "FestiCorePack"
  case assembly = "ServiceAssembly"

  var path: Path { .relativeToService(rawValue) }
}
