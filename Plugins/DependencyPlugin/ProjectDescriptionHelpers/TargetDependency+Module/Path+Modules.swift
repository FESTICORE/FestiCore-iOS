//
//  Path+Modules.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension ProjectDescription.Path {
  static func relativeToCore(_ name: String) -> Self {
    .relativeToRoot("Projects/Core/\(name)")
  }

  static func relativeToUI(_ name: String) -> Self {
    .relativeToRoot("Projects/UI/\(name)")
  }

  static func relativeToWidget(_ name: String) -> Self {
    .relativeToRoot("Projects/Widget/\(name)")
  }

  static func relativeToService(_ name: String) -> Self {
    .relativeToRoot("Projects/Service/\(name)")
  }

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
