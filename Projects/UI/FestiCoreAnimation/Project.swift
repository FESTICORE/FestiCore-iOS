//
//  Project.swift
//  FestiCoreAnimation
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreAnimation",
  product: .framework,
  dependencies: [.SPM.sdwebImage, .SPM.lottie],
  resources: ["Resources/**"],
  hasTests: true
)
