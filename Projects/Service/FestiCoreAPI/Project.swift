//
//  Project.swift
//  FestiCoreAPI
//
//  Created by FestiCore on 10/29/26.
//

import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FestiCoreAPI",
  product: .framework,
  hasTests: true
)
