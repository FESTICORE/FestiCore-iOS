//
//  DependencyValues+Storage.swift
//  FestiCoreStorage
//
//  Created by FestiCore on 10/22/26.
//

import FestiCoreStorageInterface
import Dependencies

extension SharedValueStorageDependency: DependencyKey {
  public static var liveValue: any SharedValueStorage {
    StorageFactory.sharedValueStorage
  }
}
