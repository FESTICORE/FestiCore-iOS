//
//  Project.swift
//  FeatureAssembly
//
//  Created by FestiCore on 10/23/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FeatureAssembly",
  dependencies: [
    .feature(.bearer),
    .feature(.festival),
    .feature(.login),
    .feature(.onboarding),
    .feature(.profile),
    .feature(.timetable),
    .feature(.web),
    .domain(.auth),
    .domain(.bearer),
    .domain(.festival),
    .domain(.notice),
    .domain(.timetable),
    .service(.assembly),
    .SPM.composableArchitecture
  ]
)
