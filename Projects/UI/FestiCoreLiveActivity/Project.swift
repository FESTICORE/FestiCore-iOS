//
//  Project.swift
//  FestiCoreLiveActivity
//
//  Created by FestiCore on 10/23/26.
//

import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FestiCoreLiveActivity",
  targetSettings: .settings(base: ["APPLICATION_EXTENSION_API_ONLY": "YES"])
)
