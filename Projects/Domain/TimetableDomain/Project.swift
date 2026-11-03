//
//  Project.swift
//  TimetableDomain
//
//  Created by FestiCore on 11/2/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "TimetableDomain",
  product: .framework,
  hasTests: true,
  hasInterface: true
)
