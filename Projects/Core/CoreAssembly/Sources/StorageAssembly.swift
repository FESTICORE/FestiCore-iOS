//
//  StorageAssembly.swift
//  CoreAssembly
//
//  Created by FestiCore on 10/23/26.
//

import Dependencies
import FestiCoreStorage
import FestiCoreStorageInterface

public enum StorageAssembly {
  public static func secureStorage() -> any SecureStorage {
    StorageFactory.secureStorage
  }

  public static func sharedValueStorage() -> any SharedValueStorage {
    StorageFactory.sharedValueStorage
  }

  public static func register(into values: inout DependencyValues) {
    StorageFactory.register(into: &values)
  }
}
