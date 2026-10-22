//
//  Project.swift
//  FestiCoreDesignSystem
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FestiCoreDesignSystem",
  product: .framework,
  sources: ["Sources/**", "Generated/Sources/**"],
  resources: ["Generated/Assets/**"],
  testResources: ["Tests/Resources/**"],
  hasTests: true
)
