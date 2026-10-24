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

public enum UIModule: String, CaseIterable {
  case animation = "FestiCoreAnimation"
  case designSystem = "FestiCoreDesignKit"
  case liveActivity = "FestiCoreLiveActivity"
  case sharedUI = "FestiCoreSharedUI"

  var path: Path { .relativeToUI(rawValue) }
}

public enum ServiceModule: String, CaseIterable {
  case auth = "FestiCoreAuth"
  case device = "FestiCoreDevice"
  case assembly = "ServiceAssembly"

  var path: Path { .relativeToService(rawValue) }
}
