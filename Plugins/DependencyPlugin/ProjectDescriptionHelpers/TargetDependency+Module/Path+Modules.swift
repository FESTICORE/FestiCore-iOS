//
//  Path+Modules.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension ProjectDescription.Path {
  static func relativeToFeature(_ name: String) -> Self {
    .relativeToRoot("Projects/Feature/\(name)")
  }

  static func relativeToDomain(_ name: String) -> Self {
    .relativeToRoot("Projects/Domain/\(name)")
  }

  static func relativeToData(_ name: String) -> Self {
    .relativeToRoot("Projects/Data/\(name)")
  }
}
