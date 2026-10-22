//
//  Modules.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public enum FeatureModule: String, CaseIterable {
  case home = "Home"

  var path: Path { .relativeToFeature(rawValue) }
}
