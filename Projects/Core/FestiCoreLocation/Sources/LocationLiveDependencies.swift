//
//  LocationLiveDependencies.swift
//  FestiCoreLocation
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies
import FestiCoreLocationInterface

extension LocationClientDependency: DependencyKey {
  public static var liveValue: any LocationClient {
    return CoreLocationClient()
  }
}

extension AppleMapsClientDependency: DependencyKey {
  public static var liveValue: any AppleMapsClient {
    return MapKitAppleMapsClient()
  }
}
