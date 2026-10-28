//
//  Project.swift
//  API
//
//  Created by FestiCore on 10/29/26.
//

import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "API",
  product: .framework,
  hasTests: true
)
