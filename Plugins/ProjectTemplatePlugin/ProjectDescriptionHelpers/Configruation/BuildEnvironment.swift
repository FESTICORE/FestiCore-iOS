//
//  BuildEnvironment.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public enum BuildEnvironment: String, CaseIterable {
  case stage = "Stage"
  case prod = "Prod"

  public var configurationName: ConfigurationName { .configuration(rawValue) }
  public var xcconfigPath: Path { .relativeToRoot("Config/\(rawValue).xcconfig") }
}
