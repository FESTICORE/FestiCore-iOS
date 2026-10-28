//
//  Project.swift
//  FestiCoreAPIEndpoint
//
//  Created by FestiCore on 10/29/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FestiCoreAPIEndpoint",
  product: .framework,
  dependencies: [.service(.api), .core(.network, .interface), .SPM.alamofire],
  hasTests: true
)
